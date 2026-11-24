import '../theme/illustrations.dart';
import 'diseases_fr.dart';

/// Une plante proposée sur l'écran d'accueil.
class Plant {
  const Plant({
    required this.key,
    required this.nameFr,
    required this.illustration,
    required this.imageAsset,
  });

  /// Clé telle qu'elle apparaît dans `classes.json` (`plant_of_class`).
  final String key;
  final String nameFr;
  final Illustration illustration;

  /// Photo détourée (fond transparent) affichée sur l'accueil ; l'illustration
  /// au trait sert de repli si l'image est absente.
  final String imageAsset;

  /// Nombre de maladies détectables (hors « feuille saine »).
  int get diseaseCount => DiseaseCatalog.diseaseCount(key);

  String get diseaseCountLabel {
    final n = diseaseCount;
    return n <= 1 ? '$n maladie détectée' : '$n maladies détectées';
  }

  static const tomato = Plant(
    key: 'Tomato',
    nameFr: 'Tomate',
    illustration: Illustration.tomato,
    imageAsset: 'assets/images/plants/tomato.webp',
  );
  static const potato = Plant(
    key: 'Potato',
    nameFr: 'Pomme de terre',
    illustration: Illustration.potato,
    imageAsset: 'assets/images/plants/potato.webp',
  );
  static const apple = Plant(
    key: 'Apple',
    nameFr: 'Pomme',
    illustration: Illustration.apple,
    imageAsset: 'assets/images/plants/apple.webp',
  );
  static const peach = Plant(
    key: 'Peach',
    nameFr: 'Pêche',
    illustration: Illustration.peach,
    imageAsset: 'assets/images/plants/peach.webp',
  );

  /// La plante correspondant à une clé de `classes.json` (ex. `Tomato`), si connue.
  static Plant? byKey(String key) {
    for (final p in all) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// Ordre d'affichage de la grille 2×2 (Tomate, Pomme de terre, Pomme, Pêche).
  static const all = [tomato, potato, apple, peach];
}
