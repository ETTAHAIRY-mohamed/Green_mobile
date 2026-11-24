import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare/data/plants.dart';
import 'package:plantcare/models/diagnosis.dart';
import 'package:plantcare/screens/home_screen.dart';
import 'package:plantcare/screens/result_screen.dart';
import 'package:plantcare/theme/app_theme.dart';
import 'package:plantcare/theme/plant_image.dart';
import 'package:plantcare/theme/widgets.dart';

Widget _app(Widget home) => MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: home,
    );

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556); // iPhone 16 Pro
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Diagnosis _diagnosis(DiagnosisKind kind, List<(String, double)> top) {
  return Diagnosis(
    plant: 'Tomato',
    kind: kind,
    latencyMs: 2.34,
    variantLabel: 'M5 · int8',
    rawProbabilities: const [],
    top: [
      for (final (name, p) in top)
        Prediction(className: name, plant: 'Tomato', probability: p),
    ],
  );
}

void main() {
  testWidgets('accueil : 4 plantes, sans nombre de maladies', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const HomeScreen()));

    expect(find.text('DIAGNOSTIC HORS LIGNE'), findsOneWidget);
    expect(find.byType(PlantImage), findsNWidgets(4), reason: 'une photo par plante');
    for (final plant in Plant.all) {
      expect(find.text(plant.nameFr), findsOneWidget, reason: plant.nameFr);
    }
    // Les cartes n'affichent que le nom de la plante (pas de nombre de maladies).
    expect(find.textContaining('maladie'), findsNothing);
    expect(find.textContaining('Vos photos restent sur votre téléphone'), findsOneWidget);
  });

  testWidgets('choisir une plante ouvre l\'écran photo, analyse désactivée', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(_app(const HomeScreen()));

    await tester.tap(find.text('Pomme de terre'));
    await tester.pumpAndSettle();

    expect(find.text('ÉTAPE 1 SUR 2'), findsOneWidget);
    expect(find.text('Pomme de terre'), findsOneWidget);
    expect(find.text('Ajoutez une photo de la feuille'), findsOneWidget);
    expect(find.text('Aucune photo sélectionnée'), findsOneWidget);
    expect(find.text('Galerie'), findsOneWidget);
    expect(find.text('Appareil photo'), findsOneWidget);
    expect(find.text('Lumière naturelle, sans flash'), findsOneWidget);

    final analyse = tester.widget<GoldButton>(find.byType(GoldButton));
    expect(analyse.label, 'Lancer l\'analyse');
    expect(analyse.onPressed, isNull, reason: 'pas de photo → bouton désactivé');
  });

  testWidgets('résultat : maladie détectée (écran 4)', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      _app(
        ResultScreen(
          plant: Plant.tomato,
          imagePath: '/inexistant.jpg',
          diagnosis: _diagnosis(DiagnosisKind.disease, const [
            ('Tomato___Late_blight', 0.96),
            ('Tomato___Early_blight', 0.03),
            ('Tomato___Septoria_leaf_spot', 0.01),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RÉSULTAT · TOMATE'), findsOneWidget);
    expect(find.text('Mildiou tardif'), findsOneWidget);
    expect(find.text('Phytophthora infestans'), findsOneWidget);
    expect(find.text('Maladie détectée'), findsOneWidget);
    expect(find.text('96 %'), findsOneWidget);
    expect(find.text('AUTRES POSSIBILITÉS'), findsOneWidget);
    expect(find.text('Alternariose'), findsOneWidget);
    expect(find.text('Septoriose'), findsOneWidget);
    expect(find.text('CONSEILS'), findsOneWidget);
    expect(find.text('Nouvelle analyse'), findsOneWidget);
    expect(find.textContaining('calculé hors ligne'), findsOneWidget);
  });

  testWidgets('résultat : feuille saine (écran 4b)', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      _app(
        ResultScreen(
          plant: Plant.tomato,
          imagePath: '/inexistant.jpg',
          diagnosis: _diagnosis(DiagnosisKind.healthy, const [
            ('Tomato___healthy', 0.99),
            ('Tomato___Early_blight', 0.01),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Feuille saine'), findsOneWidget);
    expect(find.text('Aucune maladie détectée'), findsOneWidget);
    expect(find.text('Maladie détectée'), findsNothing);
    expect(find.text('Nouvelle analyse'), findsOneWidget);
  });

  testWidgets('résultat : diagnostic incertain (écran 4c)', (tester) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      _app(
        ResultScreen(
          plant: Plant.tomato,
          imagePath: '/inexistant.jpg',
          diagnosis: _diagnosis(DiagnosisKind.uncertain, const [
            ('Tomato___Late_blight', 0.41),
            ('Tomato___Early_blight', 0.33),
            ('Tomato___healthy', 0.26),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Diagnostic incertain'), findsOneWidget);
    expect(find.text('Le modèle n\'est pas sûr'), findsOneWidget);
    expect(find.text('HYPOTHÈSES DU MODÈLE'), findsOneWidget);
    expect(find.text('POUR UNE MEILLEURE PHOTO'), findsOneWidget);
    expect(find.text('Reprendre la photo'), findsOneWidget);
    expect(find.text('Nouvelle analyse'), findsNothing);
    expect(find.text('CONSEILS'), findsNothing, reason: 'pas de conseil médical si incertain');
  });
}
