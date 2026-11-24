import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../config.dart';
import '../models/diagnosis.dart';
import 'class_map.dart';
import 'image_preprocessor.dart';
import 'model_registry.dart';
import 'postprocess.dart';

/// Caractéristiques du modèle chargé (variante, taille, entrée/sortie, précision).
class ModelDetails {
  const ModelDetails({
    required this.variant,
    required this.sizeBytes,
    required this.inputShape,
    required this.inputType,
    required this.inputScale,
    required this.inputZeroPoint,
    required this.outputShape,
    required this.outputType,
    this.description,
    this.accuracy,
    this.accuracyPlantFiltered,
  });

  final ModelVariant variant;
  final int sizeBytes;
  final List<int> inputShape;
  final TensorType inputType;
  final double inputScale;
  final int inputZeroPoint;
  final List<int> outputShape;
  final TensorType outputType;

  /// Texte de `model_info.json` (variante, architecture), si disponible.
  final String? description;
  final double? accuracy;
  final double? accuracyPlantFiltered;

  double get sizeKb => sizeBytes / 1000;
}

/// Résultat d'un benchmark de latence.
class BenchmarkResult {
  const BenchmarkResult({
    required this.runs,
    required this.meanMs,
    required this.minMs,
    required this.maxMs,
    required this.medianMs,
  });

  final int runs;
  final double meanMs;
  final double minMs;
  final double maxMs;
  final double medianMs;
}

/// Seule classe qui touche au moteur TFLite : charge le modèle et
/// `classes.json`, prépare l'entrée selon le type du tenseur, lance
/// l'inférence et applique le post-traitement.
///
/// L'interpréteur est chargé UNE fois (singleton) ; changer de variante le
/// recharge. Toutes les inférences passent par [_exclusive] : l'interpréteur
/// n'est pas réentrant.
class Classifier {
  Classifier._();

  static final Classifier instance = Classifier._();

  Interpreter? _interpreter;
  ClassMap? _classes;
  ModelVariant? _variant;
  ModelDetails? _details;
  Map<String, dynamic>? _modelInfo;

  late int _inputSize;
  late TensorType _inputType;
  late double _inputScale;
  late int _inputZeroPoint;
  late double _outputScale;
  late int _outputZeroPoint;
  late TensorType _outputType;

  Future<void> _queue = Future.value();

  bool get isLoaded => _interpreter != null;
  ModelVariant get variant => _variant!;
  ModelDetails get details => _details!;
  ClassMap get classes => _classes!;
  int get inputSize => _inputSize;

  /// Charge (ou recharge) un modèle. Sans argument : le modèle principal.
  Future<void> load([ModelVariant variant = kMainModel]) {
    return _exclusive(() async {
      _classes ??= ClassMap.fromJson(await rootBundle.loadString(kClassesAsset));
      _modelInfo ??= _readModelInfo(await rootBundle.loadString(kModelInfoAsset));

      final data = await rootBundle.load(variant.asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      final old = _interpreter;
      final next = Interpreter.fromBuffer(bytes);
      try {
        _configure(next, variant, bytes.length);
      } catch (_) {
        next.close();
        rethrow;
      }
      _interpreter = next;
      _variant = variant;
      old?.close();
    });
  }

  void _configure(Interpreter interpreter, ModelVariant variant, int sizeBytes) {
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    final inShape = input.shape; // ex. [1, 96, 96, 3]
    final outShape = output.shape; // ex. [1, 19]

    if (inShape.length != 4 || inShape[3] != 3) {
      throw StateError('Entrée du modèle inattendue : $inShape (attendu [1,H,W,3]).');
    }
    final classCount = outShape.reduce((a, b) => a * b);
    if (classCount != _classes!.length) {
      throw StateError(
        'Le modèle produit $classCount sorties, classes.json en décrit '
        '${_classes!.length}.',
      );
    }

    _inputSize = inShape[1];
    _inputType = input.type;
    _outputType = output.type;

    // `scale`/`zeroPoint` : ≈ 1 / 0 pour l'entrée uint8 de ce modèle.
    // Repli sur 1 / 0 si le moteur ne les renseigne pas (scale ≤ 0).
    final inParams = input.params;
    _inputScale = inParams.scale > 0 ? inParams.scale : 1.0;
    _inputZeroPoint = inParams.scale > 0 ? inParams.zeroPoint : 0;
    final outParams = output.params;
    _outputScale = outParams.scale > 0 ? outParams.scale : 1.0;
    _outputZeroPoint = outParams.scale > 0 ? outParams.zeroPoint : 0;

    final info = _infoFor(variant);
    _details = ModelDetails(
      variant: variant,
      sizeBytes: sizeBytes,
      inputShape: inShape,
      inputType: _inputType,
      inputScale: _inputScale,
      inputZeroPoint: _inputZeroPoint,
      outputShape: outShape,
      outputType: _outputType,
      description: info?['variant'] as String?,
      accuracy: (info?['test_accuracy'] as num?)?.toDouble(),
      accuracyPlantFiltered:
          (info?['test_accuracy_plant_filtered'] as num?)?.toDouble(),
    );

    debugPrint(
      '[PlantCare] modèle ${variant.file} : entrée $inShape $_inputType '
      '(scale=$_inputScale, zp=$_inputZeroPoint), sortie $outShape $_outputType, '
      '${(sizeBytes / 1000).toStringAsFixed(0)} kB',
    );
  }

  Map<String, dynamic> _readModelInfo(String source) =>
      jsonDecode(source) as Map<String, dynamic>;

  Map<String, dynamic>? _infoFor(ModelVariant variant) {
    for (final v in (_modelInfo ?? const {}).values) {
      if (v is Map<String, dynamic> && v['file'] == variant.file) return v;
    }
    return null;
  }

  // --------------------------------------------------------------- diagnostic

  /// Pipeline complet : photo → prétraitement → inférence → post-traitement.
  Future<Diagnosis> diagnose({
    required String plant,
    required String imagePath,
  }) async {
    final rgb = await ImagePreprocessor.fromFile(imagePath, _inputSize);
    return diagnoseRgb(plant: plant, rgb: rgb);
  }

  /// Diagnostic à partir d'octets RGB déjà prétraités (`size × size × 3`).
  Future<Diagnosis> diagnoseRgb({
    required String plant,
    required Uint8List rgb,
  }) {
    return _exclusive(() async {
      final run = _infer(rgb);
      debugPrint(
        '[PlantCare] probabilités brutes (${_variant!.file}, '
        '${run.ms.toStringAsFixed(2)} ms) : '
        '${run.probabilities.map((p) => p.toStringAsFixed(4)).join(', ')}',
      );
      return buildDiagnosis(
        probabilities: run.probabilities,
        classes: _classes!,
        plant: plant,
        latencyMs: run.ms,
        variantLabel: _variant!.shortLabel,
      );
    });
  }

  /// Mesure la latence : [kBenchmarkWarmup] inférences ignorées (chauffe), puis
  /// [runs] inférences chronométrées sur une entrée fixe.
  Future<BenchmarkResult> benchmark({
    int runs = kBenchmarkRuns,
    int warmup = kBenchmarkWarmup,
  }) {
    return _exclusive(() async {
      final rng = math.Random(42);
      final rgb = Uint8List.fromList(
        List<int>.generate(_inputSize * _inputSize * 3, (_) => rng.nextInt(256)),
      );
      for (var i = 0; i < warmup; i++) {
        _infer(rgb);
      }
      final times = <double>[];
      for (var i = 0; i < runs; i++) {
        times.add(_infer(rgb).ms);
        // On rend la main à l'interface de temps en temps.
        if (i % 10 == 9) await Future<void>.delayed(Duration.zero);
      }
      times.sort();
      final mean = times.reduce((a, b) => a + b) / times.length;
      return BenchmarkResult(
        runs: runs,
        meanMs: mean,
        minMs: times.first,
        maxMs: times.last,
        medianMs: times[times.length ~/ 2],
      );
    });
  }

  // ------------------------------------------------------------------ moteur

  /// Une inférence : construit le tenseur d'entrée selon son type, exécute et
  /// lit les 19 probabilités. Le chrono couvre copie d'entrée + exécution +
  /// copie de sortie (équivalent d'un `interpreter.run`).
  ({List<double> probabilities, double ms}) _infer(Uint8List rgb) {
    final expected = _inputSize * _inputSize * 3;
    if (rgb.length != expected) {
      throw ArgumentError(
        'Entrée de ${rgb.length} octets, $expected attendus '
        '($_inputSize×$_inputSize×3).',
      );
    }
    final interpreter = _interpreter!;
    final input = _buildInput(rgb);

    final sw = Stopwatch()..start();
    interpreter.runInference([input]);
    final raw = _readOutput(interpreter.getOutputTensor(0).data);
    sw.stop();

    return (probabilities: raw, ms: sw.elapsedMicroseconds / 1000.0);
  }

  /// Entrée selon le type lu dans le modèle (handoff §5.3) :
  /// - uint8   : pixels 0–255 tels quels (scale ≈ 1, zeroPoint ≈ 0) ;
  /// - float32 : pixels 0–255 en float, SANS normalisation (elle est dans le modèle) ;
  /// - int8    : quantification générique avec scale / zeroPoint du modèle.
  Uint8List _buildInput(Uint8List rgb) {
    switch (_inputType) {
      case TensorType.float32:
        final f = Float32List(rgb.length);
        for (var i = 0; i < rgb.length; i++) {
          f[i] = rgb[i].toDouble();
        }
        return f.buffer.asUint8List();
      case TensorType.uint8:
        // Le modèle annonce scale ≈ 1 (0,9993) : pixels bruts, comme en Python.
        if ((_inputScale - 1.0).abs() < 0.01 && _inputZeroPoint == 0) return rgb;
        final u = Uint8List(rgb.length);
        for (var i = 0; i < rgb.length; i++) {
          u[i] = ((rgb[i] / _inputScale).round() + _inputZeroPoint)
              .clamp(0, 255)
              .toInt();
        }
        return u;
      case TensorType.int8:
        final s = Int8List(rgb.length);
        for (var i = 0; i < rgb.length; i++) {
          s[i] = ((rgb[i] / _inputScale).round() + _inputZeroPoint)
              .clamp(-128, 127)
              .toInt();
        }
        return s.buffer.asUint8List();
      default:
        throw UnsupportedError("Type d'entrée non géré : $_inputType");
    }
  }

  /// La sortie est normalement déjà en float32 (probabilités). On gère aussi
  /// uint8/int8 par déquantification, au cas où le modèle serait remplacé.
  List<double> _readOutput(Uint8List bytes) {
    switch (_outputType) {
      case TensorType.float32:
        // Copie : `bytes` est une vue sur la mémoire du tenseur.
        final copy = Uint8List.fromList(bytes);
        return Float32List.sublistView(copy).map((v) => v.toDouble()).toList();
      case TensorType.uint8:
        return [
          for (final b in bytes) (b - _outputZeroPoint) * _outputScale,
        ];
      case TensorType.int8:
        final signed = Int8List.sublistView(Uint8List.fromList(bytes));
        return [
          for (final b in signed) (b - _outputZeroPoint) * _outputScale,
        ];
      default:
        throw UnsupportedError('Type de sortie non géré : $_outputType');
    }
  }

  /// Sérialise les accès à l'interpréteur (non réentrant).
  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
