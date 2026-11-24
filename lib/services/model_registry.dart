/// Variantes de modèle embarquées.
///
/// Pour en ajouter une (ex. M0, M4, M8 pour comparer la latence pendant la
/// soutenance) : déposer le `.tflite` dans `assets/models/`, le déclarer dans
/// `pubspec.yaml`, puis ajouter une ligne ci-dessous. L'entrée/sortie du modèle
/// est relue au chargement : rien d'autre à changer.
class ModelVariant {
  const ModelVariant({
    required this.id,
    required this.shortLabel,
    required this.subtitle,
    required this.asset,
    required this.file,
  });

  final String id;

  /// Libellé court (sélecteur, résultat), ex. « M5 · int8 ».
  final String shortLabel;

  /// Précision affichée sous le libellé.
  final String subtitle;

  /// Chemin de l'asset Flutter.
  final String asset;

  /// Nom de fichier tel qu'il apparaît dans `model_info.json`.
  final String file;
}

const ModelVariant kMainModel = ModelVariant(
  id: 'main',
  shortLabel: 'M5 · int8',
  subtitle: 'QAT int8 complet · entrée uint8',
  asset: 'assets/models/plant_model.tflite',
  file: 'plant_model.tflite',
);

const ModelVariant kBackupModel = ModelVariant(
  id: 'backup',
  shortLabel: 'M3b · float',
  subtitle: 'Dynamic range · entrée float32',
  asset: 'assets/models/plant_model_backup_float_input.tflite',
  file: 'plant_model_backup_float_input.tflite',
);

const List<ModelVariant> kModelVariants = [kMainModel, kBackupModel];

const String kClassesAsset = 'assets/models/classes.json';
const String kModelInfoAsset = 'assets/models/model_info.json';
