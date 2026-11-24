import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare/models/diagnosis.dart';
import 'package:plantcare/services/class_map.dart';
import 'package:plantcare/services/postprocess.dart';

void main() {
  final classes =
      ClassMap.fromJson(File('assets/models/classes.json').readAsStringSync());

  /// Vecteur de 19 probabilités, 0 partout sauf les classes données.
  List<double> probs(Map<String, double> values) {
    final out = List<double>.filled(classes.length, 0);
    values.forEach((name, p) {
      final i = classes.classNames.indexOf(name);
      expect(i, isNonNegative, reason: 'classe inconnue : $name');
      out[i] = p;
    });
    return out;
  }

  Diagnosis run(List<double> p, String plant, {double threshold = 0.60}) =>
      buildDiagnosis(
        probabilities: p,
        classes: classes,
        plant: plant,
        latencyMs: 1.5,
        variantLabel: 'test',
        threshold: threshold,
      );

  test('filtre par plante et renormalise à 1', () {
    final d = run(
      probs({
        'Apple___Apple_scab': 0.30, // autre plante : doit être ignorée
        'Tomato___Late_blight': 0.56,
        'Tomato___Early_blight': 0.08,
        'Tomato___healthy': 0.06,
      }),
      'Tomato',
    );
    // Total tomate = 0.70 → 0.56/0.70 = 0.80
    expect(d.best.className, 'Tomato___Late_blight');
    expect(d.best.probability, closeTo(0.80, 1e-9));
    expect(d.top.map((p) => p.plant).toSet(), {'Tomato'});
    expect(d.kind, DiagnosisKind.disease);
  });

  test('top 3 trié décroissant', () {
    final d = run(
      probs({
        'Tomato___Late_blight': 0.7,
        'Tomato___Early_blight': 0.2,
        'Tomato___Septoria_leaf_spot': 0.07,
        'Tomato___healthy': 0.03,
      }),
      'Tomato',
    );
    expect(d.top.length, 3);
    expect(
      d.top.map((p) => p.className).toList(),
      [
        'Tomato___Late_blight',
        'Tomato___Early_blight',
        'Tomato___Septoria_leaf_spot',
      ],
    );
    final probsOnly = d.top.map((p) => p.probability).toList();
    expect(probsOnly, orderedEquals([...probsOnly]..sort((a, b) => b.compareTo(a))));
  });

  test('sous le seuil de confiance : diagnostic incertain', () {
    final d = run(
      probs({
        'Tomato___Late_blight': 0.40,
        'Tomato___Early_blight': 0.35,
        'Tomato___healthy': 0.25,
      }),
      'Tomato',
    );
    expect(d.best.probability, closeTo(0.40, 1e-9));
    expect(d.kind, DiagnosisKind.uncertain);
  });

  test('le seuil est paramétrable', () {
    final p = probs({
      'Tomato___Late_blight': 0.40,
      'Tomato___Early_blight': 0.35,
      'Tomato___healthy': 0.25,
    });
    expect(run(p, 'Tomato', threshold: 0.30).kind, DiagnosisKind.disease);
    expect(run(p, 'Tomato', threshold: 0.90).kind, DiagnosisKind.uncertain);
  });

  test('classe « healthy » en tête : feuille saine', () {
    final d = run(
      probs({'Apple___healthy': 0.95, 'Apple___Black_rot': 0.05}),
      'Apple',
    );
    expect(d.kind, DiagnosisKind.healthy);
    expect(d.best.info.healthy, isTrue);
  });

  test('une plante à 2 classes renvoie 2 propositions', () {
    final d = run(
      probs({'Peach___Bacterial_spot': 0.9, 'Peach___healthy': 0.1}),
      'Peach',
    );
    expect(d.top.length, 2);
    expect(d.kind, DiagnosisKind.disease);
  });

  test('une forte probabilité hors plante ne force pas un faux résultat', () {
    // Le modèle est sûr que c\'est une pomme, mais l\'utilisateur a choisi la
    // tomate : on renormalise sur la tomate, donc la confiance reste honnête.
    final d = run(
      probs({
        'Apple___Black_rot': 0.97,
        'Tomato___Late_blight': 0.015,
        'Tomato___Early_blight': 0.015,
      }),
      'Tomato',
    );
    expect(d.best.probability, closeTo(0.5, 1e-9));
    expect(d.kind, DiagnosisKind.uncertain);
  });

  test('somme nulle : répartition égale, pas de NaN', () {
    final d = run(List<double>.filled(classes.length, 0), 'Peach');
    expect(d.best.probability, closeTo(0.5, 1e-9));
    expect(d.best.probability.isNaN, isFalse);
    expect(d.kind, DiagnosisKind.uncertain);
  });

  test('longueur de sortie incohérente ou plante inconnue : erreur claire', () {
    expect(
      () => run(List<double>.filled(5, 0.2), 'Tomato'),
      throwsArgumentError,
    );
    expect(
      () => run(List<double>.filled(classes.length, 0.05), 'Banana'),
      throwsArgumentError,
    );
  });

  test('les 19 probabilités brutes sont conservées (test de parité)', () {
    final p = probs({'Tomato___Late_blight': 0.7, 'Tomato___healthy': 0.3});
    final d = run(p, 'Tomato');
    expect(d.rawProbabilities, orderedEquals(p));
  });
}
