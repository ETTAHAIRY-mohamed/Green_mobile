import '../data/diseases_fr.dart';

/// Nature du résultat affiché (écrans 4, 4b, 4c).
enum DiagnosisKind { disease, healthy, uncertain }

/// Une classe candidate avec sa probabilité (après filtrage par plante).
class Prediction {
  const Prediction({
    required this.className,
    required this.plant,
    required this.probability,
  });

  /// Nom brut tel que dans `classes.json` (ex. `Tomato___Late_blight`).
  final String className;

  /// Clé de plante (ex. `Tomato`).
  final String plant;

  /// Probabilité renormalisée sur les classes de la plante choisie (0–1).
  final double probability;

  DiseaseInfo get info => DiseaseCatalog.lookup(plant, className);
}

/// Résultat complet d'une analyse.
class Diagnosis {
  const Diagnosis({
    required this.plant,
    required this.top,
    required this.kind,
    required this.latencyMs,
    required this.variantLabel,
    required this.rawProbabilities,
  });

  final String plant;

  /// Jusqu'à 3 prédictions, de la plus probable à la moins probable.
  final List<Prediction> top;
  final DiagnosisKind kind;

  /// Durée de `interpreter.run` seule, en millisecondes.
  final double latencyMs;

  /// Variante de modèle utilisée (pour l'affichage et le rapport).
  final String variantLabel;

  /// Les 19 probabilités brutes du modèle, dans l'ordre de `classes.json`
  /// (avant filtrage) : sert au test de parité avec le notebook.
  final List<double> rawProbabilities;

  Prediction get best => top.first;
}
