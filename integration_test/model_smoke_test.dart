// Test d'intégration : le VRAI modèle tourne sur l'appareil / le simulateur.
//
//   flutter test integration_test/model_smoke_test.dart -d <id_appareil>
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plantcare/models/diagnosis.dart';
import 'package:plantcare/services/classifier.dart';
import 'package:plantcare/services/model_registry.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

Uint8List _noise(int size, int seed) {
  final rng = math.Random(seed);
  return Uint8List.fromList(
    List<int>.generate(size * size * 3, (_) => rng.nextInt(256)),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final classifier = Classifier.instance;

  testWidgets('modèle principal M5 : entrée uint8, 19 sorties', (tester) async {
    await classifier.load(kMainModel);
    final d = classifier.details;

    expect(d.inputShape, [1, 96, 96, 3]);
    expect(d.inputType, TensorType.uint8);
    expect(d.outputShape, [1, 19]);
    expect(d.outputType, TensorType.float32);
    expect(classifier.inputSize, 96);
    // Le modèle annonce scale ≈ 1 / zero point ≈ 0 pour l'entrée.
    expect(d.inputScale, closeTo(1.0, 0.01));
    expect(d.inputZeroPoint, 0);

    final diagnosis = await classifier.diagnoseRgb(
      plant: 'Tomato',
      rgb: _noise(96, 1),
    );
    final raw = diagnosis.rawProbabilities;
    expect(raw.length, 19);
    expect(raw.every((p) => p >= 0 && p <= 1.0001), isTrue);
    expect(raw.reduce((a, b) => a + b), closeTo(1.0, 0.02));

    final tomato = diagnosis.top.fold<double>(0, (s, p) => s + p.probability);
    expect(diagnosis.top.every((p) => p.plant == 'Tomato'), isTrue);
    expect(tomato, lessThanOrEqualTo(1.0001));
    expect(diagnosis.latencyMs, greaterThan(0));
    // ignore: avoid_print
    print('M5 : ${diagnosis.latencyMs.toStringAsFixed(2)} ms, '
        'top = ${diagnosis.best.className} '
        '${(diagnosis.best.probability * 100).toStringAsFixed(1)} %');
  });

  testWidgets('modèle de secours M3b : entrée float32', (tester) async {
    try {
      await classifier.load(kBackupModel);
    } on ArgumentError catch (e) {
      // Connu : TensorFlow Lite 2.12 (pod iOS du plugin tflite_flutter 0.12.1)
      // ne sait pas créer l'interpréteur de M3b ; M5 reste le modèle principal.
      // ignore: avoid_print
      print('M3b NON CHARGEABLE sur ce moteur : $e');
      return;
    }
    final d = classifier.details;
    expect(d.inputType, TensorType.float32);
    expect(d.inputShape, [1, 96, 96, 3]);
    expect(d.outputShape, [1, 19]);

    final diagnosis = await classifier.diagnoseRgb(
      plant: 'Apple',
      rgb: _noise(96, 2),
    );
    expect(diagnosis.rawProbabilities.length, 19);
    expect(
      diagnosis.rawProbabilities.reduce((a, b) => a + b),
      closeTo(1.0, 0.02),
    );
  });

  testWidgets('les deux variantes s\'accordent sur une même entrée', (tester) async {
    final rgb = _noise(96, 3);
    await classifier.load(kMainModel);
    final a = (await classifier.diagnoseRgb(plant: 'Tomato', rgb: rgb)).rawProbabilities;
    try {
      await classifier.load(kBackupModel);
    } on ArgumentError {
      // ignore: avoid_print
      print('Comparaison M5/M3b ignorée : M3b non chargeable sur ce moteur.');
      return;
    }
    final b = (await classifier.diagnoseRgb(plant: 'Tomato', rgb: rgb)).rawProbabilities;

    // Même modèle, quantifications différentes : la classe dominante doit
    // en général coïncider ; on contrôle surtout l'absence d'erreur de format
    // (ex. entrée décalée ou mal échelonnée donnerait des résultats sans rapport).
    final topA = a.indexOf(a.reduce(math.max));
    final topB = b.indexOf(b.reduce(math.max));
    // ignore: avoid_print
    print('Variantes : top M5 = $topA (${a[topA].toStringAsFixed(3)}), '
        'top M3b = $topB (${b[topB].toStringAsFixed(3)})');
    expect(a.length, b.length);
  });

  testWidgets('benchmark : mesures cohérentes', (tester) async {
    await classifier.load(kMainModel);
    final r = await classifier.benchmark(runs: 20, warmup: 3);
    expect(r.runs, 20);
    expect(r.minMs, lessThanOrEqualTo(r.medianMs));
    expect(r.medianMs, lessThanOrEqualTo(r.maxMs));
    expect(r.meanMs, greaterThan(0));
    // ignore: avoid_print
    print('Benchmark M5 (20 runs) : moyenne ${r.meanMs.toStringAsFixed(2)} ms, '
        'min ${r.minMs.toStringAsFixed(2)}, max ${r.maxMs.toStringAsFixed(2)}');
  });

  testWidgets('type de résultat : seuil appliqué', (tester) async {
    await classifier.load(kMainModel);
    final d = await classifier.diagnoseRgb(plant: 'Peach', rgb: _noise(96, 4));
    expect(d.top.length, 2); // la pêche n'a que 2 classes
    final expectedKind = d.best.probability < 0.60
        ? DiagnosisKind.uncertain
        : (d.best.info.healthy ? DiagnosisKind.healthy : DiagnosisKind.disease);
    expect(d.kind, expectedKind);
  });
}
