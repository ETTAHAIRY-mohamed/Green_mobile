/// Table d'affichage français des 19 classes du modèle (handoff §4) + conseils.
///
/// La source de vérité des classes est `classes.json` (ordre des sorties du
/// modèle). Ici on ne fait que traduire : on associe **plante + mot-clé**
/// contenu dans le nom brut (`Plante___Maladie`), car certains mots-clés
/// existent pour plusieurs plantes (Early/Late blight, Bacterial spot).
library;

class DiseaseInfo {
  const DiseaseInfo({
    required this.nameFr,
    required this.advice,
    this.scientificName,
    this.healthy = false,
  });

  final String nameFr;
  final String? scientificName;
  final String advice;
  final bool healthy;
}

class _Entry {
  const _Entry(this.plant, this.keyword, this.info);
  final String plant;
  final String keyword;
  final DiseaseInfo info;
}

const String _healthyAdvice =
    'Aucune maladie détectée sur cette feuille. Continuez à surveiller vos '
    'plants régulièrement, arrosez au pied plutôt que sur le feuillage et '
    'gardez les plants bien aérés.';

const List<_Entry> _entries = [
  // ---- Tomate (10 classes) ----
  _Entry(
    'Tomato',
    'Bacterial_spot',
    DiseaseInfo(
      nameFr: 'Tache bactérienne',
      scientificName: 'Xanthomonas spp.',
      advice:
          'Retirez les feuilles atteintes, évitez d\'arroser sur le feuillage et '
          'ne touchez pas les plants mouillés. Utilisez des semences saines et '
          'alternez les cultures. Si la maladie s\'étend, demandez l\'avis d\'un '
          'conseiller agricole.',
    ),
  ),
  _Entry(
    'Tomato',
    'Early_blight',
    DiseaseInfo(
      nameFr: 'Alternariose',
      scientificName: 'Alternaria solani',
      advice:
          'Éliminez les feuilles basses atteintes, paillez le sol pour limiter '
          'les éclaboussures et espacez les plants pour les aérer. Alternez les '
          'cultures d\'une année sur l\'autre.',
    ),
  ),
  _Entry(
    'Tomato',
    'Late_blight',
    DiseaseInfo(
      nameFr: 'Mildiou tardif',
      scientificName: 'Phytophthora infestans',
      advice:
          'Retirez et détruisez les feuilles atteintes, évitez de mouiller le '
          'feuillage à l\'arrosage et aérez les plants. Si la maladie s\'étend, '
          'demandez l\'avis d\'un conseiller agricole.',
    ),
  ),
  _Entry(
    'Tomato',
    'Leaf_Mold',
    DiseaseInfo(
      nameFr: 'Cladosporiose',
      scientificName: 'Passalora fulva',
      advice:
          'Aérez fortement la culture (surtout sous abri), réduisez l\'humidité, '
          'évitez de mouiller les feuilles et retirez celles qui sont atteintes. '
          'Privilégiez des variétés résistantes.',
    ),
  ),
  _Entry(
    'Tomato',
    'Septoria_leaf_spot',
    DiseaseInfo(
      nameFr: 'Septoriose',
      scientificName: 'Septoria lycopersici',
      advice:
          'Retirez les feuilles basses tachetées, arrosez au pied, paillez et '
          'évitez de travailler dans le feuillage mouillé. Nettoyez les débris '
          'en fin de saison et alternez les cultures.',
    ),
  ),
  _Entry(
    'Tomato',
    'Spider_mites',
    DiseaseInfo(
      nameFr: 'Acariens (tétranyque tisserand)',
      scientificName: 'Tetranychus urticae',
      advice:
          'Regardez le dessous des feuilles (fines toiles, points jaunes). '
          'Les acariens aiment l\'air chaud et sec : bassinez le feuillage, '
          'retirez les feuilles très atteintes et favorisez les auxiliaires '
          '(coccinelles, acariens prédateurs).',
    ),
  ),
  _Entry(
    'Tomato',
    'Target_Spot',
    DiseaseInfo(
      nameFr: 'Corynesporiose (tache cible)',
      scientificName: 'Corynespora cassiicola',
      advice:
          'Retirez les feuilles atteintes, aérez les plants, évitez l\'excès '
          'd\'humidité et d\'azote, et alternez les cultures. Demandez conseil si '
          'les taches gagnent les fruits.',
    ),
  ),
  _Entry(
    'Tomato',
    'Yellow_Leaf_Curl_Virus',
    DiseaseInfo(
      nameFr: 'Virus des feuilles jaunes en cuillère (TYLCV)',
      scientificName: 'Begomovirus',
      advice:
          'Maladie virale transmise par les aleurodes (mouches blanches), sans '
          'traitement curatif. Arrachez et détruisez les plants atteints, '
          'contrôlez les aleurodes (filets, pièges jaunes) et choisissez des '
          'variétés tolérantes.',
    ),
  ),
  _Entry(
    'Tomato',
    'mosaic_virus',
    DiseaseInfo(
      nameFr: 'Virus de la mosaïque de la tomate (ToMV)',
      scientificName: 'Tobamovirus',
      advice:
          'Maladie virale très contagieuse, sans traitement. Arrachez et '
          'détruisez les plants atteints, désinfectez vos outils et vos mains, '
          'et utilisez des semences saines ou des variétés résistantes.',
    ),
  ),
  _Entry(
    'Tomato',
    'healthy',
    DiseaseInfo(nameFr: 'Feuille saine', advice: _healthyAdvice, healthy: true),
  ),

  // ---- Pomme de terre (3 classes) ----
  _Entry(
    'Potato',
    'Early_blight',
    DiseaseInfo(
      nameFr: 'Alternariose',
      scientificName: 'Alternaria solani',
      advice:
          'Retirez les feuilles atteintes, veillez à une fertilisation et un '
          'arrosage réguliers (les plantes stressées sont plus sensibles) et '
          'alternez les cultures.',
    ),
  ),
  _Entry(
    'Potato',
    'Late_blight',
    DiseaseInfo(
      nameFr: 'Mildiou tardif',
      scientificName: 'Phytophthora infestans',
      advice:
          'Maladie à progression rapide par temps humide : retirez et détruisez '
          'les feuilles atteintes, n\'arrosez pas sur le feuillage, buttez bien '
          'les plants et demandez l\'avis d\'un conseiller agricole sans '
          'attendre.',
    ),
  ),
  _Entry(
    'Potato',
    'healthy',
    DiseaseInfo(nameFr: 'Feuille saine', advice: _healthyAdvice, healthy: true),
  ),

  // ---- Pomme (4 classes) ----
  _Entry(
    'Apple',
    'Apple_scab',
    DiseaseInfo(
      nameFr: 'Tavelure',
      scientificName: 'Venturia inaequalis',
      advice:
          'Ramassez et détruisez les feuilles tombées à l\'automne (elles '
          'abritent le champignon), taillez pour aérer la ramure et choisissez '
          'des variétés peu sensibles. Demandez un conseil de protection si '
          'nécessaire.',
    ),
  ),
  _Entry(
    'Apple',
    'Black_rot',
    DiseaseInfo(
      nameFr: 'Pourriture noire',
      scientificName: 'Botryosphaeria obtusa',
      advice:
          'Taillez et détruisez les branches chancreuses et les fruits '
          'momifiés, désinfectez les outils de taille et évitez les blessures '
          'sur l\'arbre.',
    ),
  ),
  _Entry(
    'Apple',
    'Cedar_apple_rust',
    DiseaseInfo(
      nameFr: 'Rouille grillagée du pommier',
      scientificName: 'Gymnosporangium juniperi-virginianae',
      advice:
          'Le champignon alterne entre le pommier et les genévriers ou cèdres '
          'proches : si possible, éloignez-les ou taillez-les, et retirez les '
          'feuilles atteintes. Demandez un conseil de protection au printemps.',
    ),
  ),
  _Entry(
    'Apple',
    'healthy',
    DiseaseInfo(nameFr: 'Feuille saine', advice: _healthyAdvice, healthy: true),
  ),

  // ---- Pêche (2 classes) ----
  _Entry(
    'Peach',
    'Bacterial_spot',
    DiseaseInfo(
      nameFr: 'Tache bactérienne',
      scientificName: 'Xanthomonas arboricola pv. pruni',
      advice:
          'Taillez par temps sec, retirez les rameaux et feuilles atteints, '
          'évitez l\'excès d\'azote et les blessures, et choisissez des '
          'variétés tolérantes. Demandez l\'avis d\'un conseiller pour la '
          'protection.',
    ),
  ),
  _Entry(
    'Peach',
    'healthy',
    DiseaseInfo(nameFr: 'Feuille saine', advice: _healthyAdvice, healthy: true),
  ),
];

class DiseaseCatalog {
  DiseaseCatalog._();

  /// Nombre de maladies (hors « saine ») pour une plante, d'après la table.
  static int diseaseCount(String plant) => _entries
      .where((e) => e.plant == plant && !e.info.healthy)
      .length;

  /// Toutes les entrées d'une plante (utile aux tests).
  static int entryCount(String plant) =>
      _entries.where((e) => e.plant == plant).length;

  /// Traduit un nom brut de classe (`Tomato___Late_blight`) pour une plante.
  ///
  /// Ne renvoie jamais `null` : une classe inconnue (nouveau modèle) retombe
  /// sur son nom brut, lisible, avec un conseil générique.
  static DiseaseInfo lookup(String plant, String rawClassName) {
    for (final e in _entries) {
      if (e.plant == plant && rawClassName.contains(e.keyword)) return e.info;
    }
    return _fallback(rawClassName);
  }

  static DiseaseInfo _fallback(String raw) {
    final disease = raw.contains('___') ? raw.split('___').last : raw;
    final pretty = disease.replaceAll('_', ' ').trim();
    final healthy = raw.toLowerCase().endsWith('healthy');
    return DiseaseInfo(
      nameFr: healthy ? 'Feuille saine' : pretty,
      advice: healthy
          ? _healthyAdvice
          : 'Retirez les feuilles atteintes, aérez les plants et demandez '
              'l\'avis d\'un conseiller agricole.',
      healthy: healthy,
    );
  }
}
