import '../data/plants.dart';
import 'diagnosis.dart';

/// Une analyse enregistrée dans l'historique (stockée sur le téléphone).
///
/// On garde le strict nécessaire pour ré-afficher l'écran de résultat :
/// plante, nature du résultat, jusqu'à 3 hypothèses, durée et variante du
/// modèle. La photo n'est conservée que sous forme de petite vignette
/// (voir `HistoryStore`).
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.plantKey,
    required this.kind,
    required this.top,
    required this.latencyMs,
    required this.variantLabel,
    required this.analyzedAt,
  });

  /// Identifiant unique (millisecondes depuis 1970 + compteur).
  final String id;

  /// Clé de plante (ex. `Tomato`).
  final String plantKey;
  final DiagnosisKind kind;

  /// Jusqu'à 3 prédictions, de la plus probable à la moins probable.
  final List<Prediction> top;
  final double latencyMs;
  final String variantLabel;
  final DateTime analyzedAt;

  Prediction get best => top.first;

  Plant? get plant => Plant.byKey(plantKey);

  String get plantNameFr => plant?.nameFr ?? plantKey;

  /// Titre affiché dans la liste (même logique que l'écran de résultat).
  String get title => switch (kind) {
        DiagnosisKind.disease => best.info.nameFr,
        DiagnosisKind.healthy => 'Feuille saine',
        DiagnosisKind.uncertain => 'Diagnostic incertain',
      };

  /// Reconstitue le [Diagnosis] pour rouvrir l'écran de résultat.
  Diagnosis toDiagnosis() => Diagnosis(
        plant: plantKey,
        top: top,
        kind: kind,
        latencyMs: latencyMs,
        variantLabel: variantLabel,
        rawProbabilities: const [],
      );

  factory HistoryEntry.fromDiagnosis(
    Diagnosis d, {
    required String id,
    required DateTime analyzedAt,
  }) {
    return HistoryEntry(
      id: id,
      plantKey: d.plant,
      kind: d.kind,
      top: d.top.take(3).toList(growable: false),
      latencyMs: d.latencyMs,
      variantLabel: d.variantLabel,
      analyzedAt: analyzedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'plant': plantKey,
        'kind': kind.name,
        'top': [
          for (final p in top) {'c': p.className, 'p': p.probability},
        ],
        'ms': latencyMs,
        'variant': variantLabel,
        'at': analyzedAt.millisecondsSinceEpoch,
      };

  /// Lève une [FormatException] si les données sont inutilisables : le
  /// stockage ignore alors l'entrée au lieu de planter.
  factory HistoryEntry.fromJson(Map<String, Object?> json) {
    try {
      final plant = json['plant']! as String;
      final top = [
        for (final raw in json['top']! as List<Object?>)
          Prediction(
            className: (raw! as Map)['c']! as String,
            plant: plant,
            probability: ((raw as Map)['p']! as num).toDouble(),
          ),
      ];
      if (top.isEmpty) throw const FormatException('aucune prédiction');
      return HistoryEntry(
        id: json['id']! as String,
        plantKey: plant,
        kind: DiagnosisKind.values.byName(json['kind']! as String),
        top: top,
        latencyMs: (json['ms']! as num).toDouble(),
        variantLabel: json['variant']! as String,
        analyzedAt: DateTime.fromMillisecondsSinceEpoch(json['at']! as int),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('entrée d\'historique invalide : $e');
    }
  }
}
