import 'dart:convert';

/// Contenu de `classes.json` : l'ORDRE de `class_names` est l'ordre des
/// sorties du modèle. Ne jamais coder cet ordre en dur dans l'application.
class ClassMap {
  const ClassMap({
    required this.classNames,
    required this.plantOfClass,
    required this.plants,
  });

  /// Noms bruts, ex. `Tomato___Late_blight`, dans l'ordre des sorties.
  final List<String> classNames;

  /// Plante de chaque classe (même longueur que [classNames]).
  final List<String> plantOfClass;

  /// Plantes gérées (ex. `Tomato`, `Potato`, `Apple`, `Peach`).
  final List<String> plants;

  int get length => classNames.length;

  factory ClassMap.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final names = List<String>.from(json['class_names'] as List);
    final plantOf = List<String>.from(json['plant_of_class'] as List);
    if (names.length != plantOf.length) {
      throw FormatException(
        'classes.json incohérent : ${names.length} classes mais '
        '${plantOf.length} plantes.',
      );
    }
    return ClassMap(
      classNames: names,
      plantOfClass: plantOf,
      plants: List<String>.from(json['plants'] as List),
    );
  }

  /// Indices des classes appartenant à [plant].
  List<int> indicesOf(String plant) => [
        for (var i = 0; i < plantOfClass.length; i++)
          if (plantOfClass[i] == plant) i,
      ];
}
