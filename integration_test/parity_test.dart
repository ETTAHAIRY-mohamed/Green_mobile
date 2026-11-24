// Test de parité avec le notebook Python (handoff §6 bis, point 5).
//
// Passe les photos de test (dossier `images_test_plantcare` + `attendu.csv`)
// dans le VRAI pipeline de l'application (EXIF → carré central → 96×96 → modèle
// → filtre par plante) et compare maladie et confiance à celles obtenues en Python.
//
//   flutter test integration_test/parity_test.dart -d <id_appareil> \
//       --dart-define=PARITY_DIR=/chemin/vers/dossier_contenant_attendu.csv
//
// PARITY_DIR contient `attendu.csv` et `images_test_plantcare/images_test_plantcare/`.
// Sans PARITY_DIR, le test est ignoré.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:plantcare/services/classifier.dart';
import 'package:plantcare/services/image_preprocessor.dart';
import 'package:plantcare/services/model_registry.dart';

const String _dir = String.fromEnvironment('PARITY_DIR');

/// `--dart-define=RESIZE=linear|cubic|average` pour comparer les méthodes de
/// redimensionnement (défaut : celle de l'application).
const String _resize = String.fromEnvironment('RESIZE', defaultValue: 'average');

img.Interpolation get _interpolation => switch (_resize) {
      'linear' => img.Interpolation.linear,
      'cubic' => img.Interpolation.cubic,
      'nearest' => img.Interpolation.nearest,
      _ => img.Interpolation.average,
    };

const Map<String, String> _plantKey = {
  'Tomate': 'Tomato',
  'Pomme de terre': 'Potato',
  'Pomme': 'Apple',
  'Pêche': 'Peach',
};

class _Row {
  _Row(this.file, this.plant, this.label, this.className, this.confidence);
  final String file;
  final String plant;
  final String label;
  final String className;
  final double confidence;
}

List<_Row> _readCsv(String path) {
  final text = File(path).readAsStringSync().replaceFirst('﻿', '');
  final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty);
  return [
    for (final line in lines.skip(1))
      () {
        final c = line.split(';');
        final conf = double.parse(
          c[4].replaceAll('%', '').replaceAll(',', '.').trim(),
        );
        return _Row(c[0].trim(), c[1].trim(), c[2].trim(), c[3].trim(), conf / 100);
      }(),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'parité avec Python sur les 38 photos de test',
    skip: _dir.isEmpty,
    (tester) async {
      final classifier = Classifier.instance;
      await classifier.load(kMainModel);

      final rows = _readCsv('$_dir/attendu.csv');
      final base = '$_dir/images_test_plantcare/images_test_plantcare';
      expect(rows.length, 38);

      var classOk = 0;
      var maxDiff = 0.0;
      var sumDiff = 0.0;
      final failures = <String>[];
      final buffer = StringBuffer()
        ..writeln('fichier | attendu (Python) | app | écart');

      for (final r in rows) {
        final path = '$base/${r.file}';
        expect(File(path).existsSync(), isTrue, reason: 'image absente : $path');

        // Même chemin que l'écran d'analyse : prétraitement (Isolate) puis modèle.
        final rgb = await ImagePreprocessor.fromFile(
          path,
          classifier.inputSize,
          interpolation: _interpolation,
        );
        final d = await classifier.diagnoseRgb(
          plant: _plantKey[r.plant]!,
          rgb: rgb,
        );
        final same = d.best.className == r.className;
        final diff = (d.best.probability - r.confidence).abs();
        if (same) classOk++;
        maxDiff = diff > maxDiff ? diff : maxDiff;
        sumDiff += diff;

        buffer.writeln(
          '${r.file.split('/').last} | ${r.className} '
          '${(r.confidence * 100).toStringAsFixed(1)} % | '
          '${d.best.className} ${(d.best.probability * 100).toStringAsFixed(1)} % '
          '(${d.kind.name}, ${d.latencyMs.toStringAsFixed(2)} ms) | '
          '${(diff * 100).toStringAsFixed(1)} pts ${same ? '' : '  <-- CLASSE DIFFERENTE'}',
        );
        if (!same) failures.add('${r.file}: attendu ${r.className}, obtenu ${d.best.className}');
      }

      buffer
        ..writeln('---')
        ..writeln('Même classe : $classOk / ${rows.length}')
        ..writeln('Écart moyen de confiance : ${(sumDiff / rows.length * 100).toStringAsFixed(2)} pts')
        ..writeln('Écart maximal de confiance : ${(maxDiff * 100).toStringAsFixed(2)} pts');
      // ignore: avoid_print
      print('\n$buffer');

      expect(failures, isEmpty, reason: failures.join('\n'));
      // Quelques points d'écart sont normaux (méthode de redimensionnement) ;
      // un écart moyen élevé trahirait un problème de prétraitement.
      expect(sumDiff / rows.length, lessThan(0.03),
          reason: 'écart moyen de confiance > 3 points');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
