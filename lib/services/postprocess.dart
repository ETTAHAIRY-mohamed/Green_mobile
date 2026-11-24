import '../config.dart';
import '../models/diagnosis.dart';
import 'class_map.dart';

/// Post-traitement du handoff §6 (étapes 7 à 10), sans aucune dépendance au
/// moteur TFLite : testable directement.
///
/// 1. garder seulement les classes de la plante choisie ;
/// 2. renormaliser ces probabilités pour qu'elles somment à 1 ;
/// 3. trier → top 3 ;
/// 4. top 1 < seuil → « incertain » ; sinon « saine » ou « maladie ».
Diagnosis buildDiagnosis({
  required List<double> probabilities,
  required ClassMap classes,
  required String plant,
  required double latencyMs,
  required String variantLabel,
  double threshold = kConfidenceThreshold,
  int topK = 3,
}) {
  if (probabilities.length != classes.length) {
    throw ArgumentError(
      'Le modèle a produit ${probabilities.length} sorties mais classes.json '
      'en décrit ${classes.length}.',
    );
  }
  final indices = classes.indicesOf(plant);
  if (indices.isEmpty) {
    throw ArgumentError('Plante inconnue dans classes.json : $plant');
  }

  var sum = 0.0;
  for (final i in indices) {
    sum += probabilities[i];
  }

  final predictions = [
    for (final i in indices)
      Prediction(
        className: classes.classNames[i],
        plant: plant,
        // Somme nulle (cas dégénéré) : on répartit à parts égales.
        probability: sum > 1e-12 ? probabilities[i] / sum : 1 / indices.length,
      ),
  ]..sort((a, b) => b.probability.compareTo(a.probability));

  final top = predictions.take(topK).toList(growable: false);
  final best = top.first;

  final DiagnosisKind kind;
  if (best.probability < threshold) {
    kind = DiagnosisKind.uncertain;
  } else if (best.className.toLowerCase().endsWith('healthy')) {
    kind = DiagnosisKind.healthy;
  } else {
    kind = DiagnosisKind.disease;
  }

  return Diagnosis(
    plant: plant,
    top: top,
    kind: kind,
    latencyMs: latencyMs,
    variantLabel: variantLabel,
    rawProbabilities: List<double>.unmodifiable(probabilities),
  );
}
