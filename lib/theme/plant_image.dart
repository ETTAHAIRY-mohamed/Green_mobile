import 'package:flutter/material.dart';

import '../data/plants.dart';
import 'illustrations.dart';

/// Tag Hero commun à la carte de l'accueil et à l'en-tête de l'écran photo :
/// le fruit « voyage » d'un écran à l'autre.
String plantHeroTag(Plant plant) => 'plant-${plant.key}';

/// Photo détourée d'une plante (accueil, en-tête de l'écran photo).
/// Repli sur l'illustration au trait si l'image est introuvable.
class PlantImage extends StatelessWidget {
  const PlantImage(
    this.plant, {
    super.key,
    required this.width,
    required this.height,
  });

  final Plant plant;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        plant.imageAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => Center(
          child: IllustrationView(plant.illustration, size: height * 0.85),
        ),
      ),
    );
  }
}
