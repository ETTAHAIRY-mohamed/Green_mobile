/// Réglages centraux de l'application (faciles à modifier).
library;

/// Seuil de confiance : sous cette valeur (après filtrage par plante),
/// l'application affiche « Diagnostic incertain » au lieu d'un résultat.
/// À ajuster avec nos photos de test.
const double kConfidenceThreshold = 0.60;

/// Taille (côté, en pixels) attendue par le modèle. Elle est relue depuis le
/// modèle au chargement ; cette valeur ne sert que de repli.
const int kInputSize = 96;

/// Durée minimale de l'écran « Analyse en cours » (l'inférence est très rapide).
const Duration kMinAnalysisDuration = Duration(milliseconds: 1200);

/// Benchmark de latence (valeurs par défaut, utilisées par `integration_test/model_smoke_test.dart`).
const int kBenchmarkWarmup = 5;
const int kBenchmarkRuns = 50;
