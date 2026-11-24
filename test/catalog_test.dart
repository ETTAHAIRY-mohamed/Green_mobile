import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare/data/diseases_fr.dart';
import 'package:plantcare/data/plants.dart';
import 'package:plantcare/services/class_map.dart';

ClassMap _loadClasses() =>
    ClassMap.fromJson(File('assets/models/classes.json').readAsStringSync());

void main() {
  final classes = _loadClasses();

  test('classes.json : 19 classes, 4 plantes, tableaux alignés', () {
    expect(classes.length, 19);
    expect(classes.plantOfClass.length, 19);
    expect(classes.plants.toSet(), {'Tomato', 'Potato', 'Apple', 'Peach'});
  });

  test('chaque classe a une entrée française propre (pas de repli)', () {
    for (var i = 0; i < classes.length; i++) {
      final plant = classes.plantOfClass[i];
      final raw = classes.classNames[i];
      final info = DiseaseCatalog.lookup(plant, raw);
      // Le repli reprend le nom brut ; une vraie entrée a un nom FR traduit
      // et, pour une maladie, un nom scientifique.
      expect(info.advice, isNotEmpty, reason: raw);
      if (info.healthy) {
        expect(info.nameFr, 'Feuille saine', reason: raw);
      } else {
        expect(info.scientificName, isNotNull, reason: 'Pas de traduction pour $raw');
      }
    }
  });

  test('les noms français sont uniques au sein d\'une plante', () {
    for (final plant in classes.plants) {
      final names = [
        for (final i in classes.indicesOf(plant))
          DiseaseCatalog.lookup(plant, classes.classNames[i]).nameFr,
      ];
      expect(names.toSet().length, names.length, reason: '$plant : $names');
    }
  });

  test('l\'ambiguïté plante + mot-clé est bien gérée', () {
    // Early/Late blight : tomate ET pomme de terre ; Bacterial spot : tomate ET pêche.
    expect(
      DiseaseCatalog.lookup('Tomato', 'Tomato___Bacterial_spot').scientificName,
      'Xanthomonas spp.',
    );
    expect(
      DiseaseCatalog.lookup('Peach', 'Peach___Bacterial_spot').scientificName,
      'Xanthomonas arboricola pv. pruni',
    );
    expect(
      DiseaseCatalog.lookup('Tomato', 'Tomato___Late_blight').nameFr,
      'Mildiou tardif',
    );
    expect(
      DiseaseCatalog.lookup('Potato', 'Potato___Early_blight').nameFr,
      'Alternariose',
    );
  });

  test('noms bruts réels du modèle (variantes de graphie)', () {
    expect(
      DiseaseCatalog.lookup(
        'Tomato',
        'Tomato___Spider_mites Two-spotted_spider_mite',
      ).nameFr,
      'Acariens (tétranyque tisserand)',
    );
    expect(
      DiseaseCatalog.lookup('Tomato', 'Tomato___Tomato_mosaic_virus').scientificName,
      'Tobamovirus',
    );
    expect(
      DiseaseCatalog.lookup('Tomato', 'Tomato___Tomato_Yellow_Leaf_Curl_Virus')
          .scientificName,
      'Begomovirus',
    );
  });

  test('nombres de maladies affichés sur l\'accueil (design)', () {
    expect(Plant.tomato.diseaseCount, 9);
    expect(Plant.potato.diseaseCount, 2);
    expect(Plant.apple.diseaseCount, 3);
    expect(Plant.peach.diseaseCount, 1);
    expect(Plant.tomato.diseaseCountLabel, '9 maladies détectées');
    expect(Plant.peach.diseaseCountLabel, '1 maladie détectée');
  });

  test('une classe inconnue retombe sur un affichage lisible', () {
    final info = DiseaseCatalog.lookup('Tomato', 'Tomato___Brand_new_disease');
    expect(info.nameFr, 'Brand new disease');
    expect(info.healthy, isFalse);
  });
}
