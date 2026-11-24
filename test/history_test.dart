import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantcare/models/diagnosis.dart';
import 'package:plantcare/models/history_entry.dart';
import 'package:plantcare/screens/history_screen.dart';
import 'package:plantcare/screens/home_screen.dart';
import 'package:plantcare/services/history_store.dart';
import 'package:plantcare/theme/app_theme.dart';
import 'package:plantcare/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: home,
    );

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Diagnosis _diagnosis({
  DiagnosisKind kind = DiagnosisKind.disease,
  String plant = 'Tomato',
  List<(String, double)> top = const [
    ('Tomato___Late_blight', 0.96),
    ('Tomato___Early_blight', 0.03),
    ('Tomato___Septoria_leaf_spot', 0.01),
  ],
}) {
  return Diagnosis(
    plant: plant,
    kind: kind,
    latencyMs: 1.8,
    variantLabel: 'M5 · int8',
    rawProbabilities: const [],
    top: [
      for (final (name, p) in top)
        Prediction(className: name, plant: plant, probability: p),
    ],
  );
}

HistoryEntry _entry(
  String id,
  DateTime at, {
  DiagnosisKind kind = DiagnosisKind.disease,
  String plant = 'Tomato',
  List<(String, double)>? top,
}) {
  return HistoryEntry.fromDiagnosis(
    top == null
        ? _diagnosis(kind: kind, plant: plant)
        : _diagnosis(kind: kind, plant: plant, top: top),
    id: id,
    analyzedAt: at,
  );
}

Uint8List _png(int w, int h, {required img.Color left, required img.Color right}) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixel(x, y, x < w ~/ 2 ? left : right);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HistoryEntry', () {
    test('JSON aller-retour', () {
      final e = _entry('42-0', DateTime(2026, 11, 22, 14, 37), kind: DiagnosisKind.healthy);
      final back = HistoryEntry.fromJson(
        Map<String, Object?>.from(jsonDecode(jsonEncode(e.toJson())) as Map),
      );
      expect(back.id, '42-0');
      expect(back.plantKey, 'Tomato');
      expect(back.kind, DiagnosisKind.healthy);
      expect(back.top.length, 3);
      expect(back.best.className, 'Tomato___Late_blight');
      expect(back.best.probability, closeTo(0.96, 1e-9));
      expect(back.analyzedAt, DateTime(2026, 11, 22, 14, 37));
      expect(back.title, 'Feuille saine');
    });

    test('titre selon la nature du résultat', () {
      final at = DateTime(2026, 11, 22);
      expect(_entry('a', at).title, 'Mildiou tardif');
      expect(_entry('b', at, kind: DiagnosisKind.uncertain).title, 'Diagnostic incertain');
    });

    test('données invalides : FormatException', () {
      expect(() => HistoryEntry.fromJson({'id': 'x'}), throwsFormatException);
      expect(
        () => HistoryEntry.fromJson({
          'id': 'x', 'plant': 'Tomato', 'kind': 'inconnu', 'top': <Object?>[],
          'ms': 1, 'variant': 'v', 'at': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('makeThumbnailJpeg', () {
    test('carré central 144×144, couleurs conservées', () {
      // 400×200 : moitié gauche rouge, moitié droite bleue. Le carré central
      // (x 100–300) garde donc une moitié de chaque.
      final src = _png(400, 200, left: img.ColorRgb8(220, 20, 20), right: img.ColorRgb8(20, 20, 220));
      final jpg = makeThumbnailJpeg(src);
      final out = img.decodeJpg(jpg)!;
      expect((out.width, out.height), (kThumbnailSize, kThumbnailSize));
      final l = out.getPixel(10, 72);
      final r = out.getPixel(kThumbnailSize - 10, 72);
      expect(l.r, greaterThan(150));
      expect(l.b, lessThan(90));
      expect(r.b, greaterThan(150));
      expect(r.r, lessThan(90));
      expect(jpg.length, lessThan(15000), reason: 'vignette légère');
    });

    test('image illisible : FormatException', () {
      expect(() => makeThumbnailJpeg(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
  });

  group('HistoryStore', () {
    late Directory tmp;
    late String photo;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('plantcare_history_');
      photo = '${tmp.path}/leaf.png';
      File(photo).writeAsBytesSync(
        _png(300, 200, left: img.ColorRgb8(40, 160, 60), right: img.ColorRgb8(60, 140, 40)),
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('enregistre, puis retrouve l\'analyse et sa vignette après redémarrage', () async {
      final store = HistoryStore();
      final saved = await store.record(
        diagnosis: _diagnosis(),
        imagePath: photo,
        now: DateTime(2026, 11, 22, 9, 5),
      );
      expect(saved, isNotNull);
      expect(store.entries.value.length, 1);
      expect(store.thumbnail(saved!.id), isNotNull);

      // « Redémarrage » : nouveau store, mêmes préférences.
      final reopened = HistoryStore();
      await reopened.ensureLoaded();
      expect(reopened.entries.value.length, 1);
      final e = reopened.entries.value.single;
      expect(e.title, 'Mildiou tardif');
      expect(e.analyzedAt, DateTime(2026, 11, 22, 9, 5));
      expect(reopened.thumbnail(e.id), isNotNull);
      expect(img.decodeJpg(reopened.thumbnail(e.id)!), isNotNull);
    });

    test('plus récent en premier ; photo illisible : analyse gardée sans vignette', () async {
      final store = HistoryStore();
      await store.record(diagnosis: _diagnosis(), imagePath: photo, now: DateTime(2026, 11, 20));
      final broken = await store.record(
        diagnosis: _diagnosis(kind: DiagnosisKind.healthy, top: const [('Tomato___healthy', 0.99)]),
        imagePath: '${tmp.path}/absente.jpg',
        now: DateTime(2026, 11, 21),
      );
      expect(store.entries.value.map((e) => e.analyzedAt.day), [20, 21].reversed.toList());
      expect(store.thumbnail(broken!.id), isNull);
      expect(store.entries.value.first.kind, DiagnosisKind.healthy);
    });

    test('plafond de $kHistoryMaxEntries analyses : les plus anciennes partent', () async {
      final store = HistoryStore();
      final base = DateTime(2026, 1, 1);
      for (var i = 0; i < kHistoryMaxEntries + 3; i++) {
        await store.record(
          diagnosis: _diagnosis(),
          imagePath: '${tmp.path}/absente.jpg',
          now: base.add(Duration(minutes: i)),
        );
      }
      final list = store.entries.value;
      expect(list.length, kHistoryMaxEntries);
      expect(list.first.analyzedAt, base.add(Duration(minutes: kHistoryMaxEntries + 2)));
      expect(list.last.analyzedAt, base.add(const Duration(minutes: 3)));

      final reopened = HistoryStore();
      await reopened.ensureLoaded();
      expect(reopened.entries.value.length, kHistoryMaxEntries);
    });

    test('supprime une analyse (et sa vignette), puis efface tout', () async {
      final store = HistoryStore();
      final a = await store.record(diagnosis: _diagnosis(), imagePath: photo, now: DateTime(2026, 11, 20));
      final b = await store.record(diagnosis: _diagnosis(), imagePath: photo, now: DateTime(2026, 11, 21));

      await store.remove(a!.id);
      expect(store.entries.value.map((e) => e.id), [b!.id]);
      expect(store.thumbnail(a.id), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains(a.id)), isEmpty,
          reason: 'la vignette supprimée ne reste pas dans les préférences');

      await store.clear();
      expect(store.entries.value, isEmpty);
      final reopened = HistoryStore();
      await reopened.ensureLoaded();
      expect(reopened.entries.value, isEmpty);
      expect(prefs.getKeys().where((k) => k.startsWith('plantcare.history.thumb.')), isEmpty);
    });

    test('JSON corrompu : historique vide, sans exception', () async {
      SharedPreferences.setMockInitialValues({'plantcare.history.v1': '{pas du json'});
      final store = HistoryStore();
      await store.ensureLoaded();
      expect(store.entries.value, isEmpty);
      expect(store.isLoaded, isTrue);
    });

    test('entrée invalide ignorée, les autres sont conservées', () async {
      final good = _entry('g-1', DateTime(2026, 11, 22)).toJson();
      SharedPreferences.setMockInitialValues({
        'plantcare.history.v1':
            '[${jsonEncode(good)}, {"id": "mauvaise"}, 7]',
      });
      final store = HistoryStore();
      await store.ensureLoaded();
      expect(store.entries.value.map((e) => e.id), ['g-1']);
    });
  });

  group('dates françaises', () {
    final now = DateTime(2026, 11, 22, 18, 0);
    test('dayLabel', () {
      expect(dayLabel(DateTime(2026, 11, 22, 0, 5), now: now), 'Aujourd\'hui');
      expect(dayLabel(DateTime(2026, 11, 21, 23, 59), now: now), 'Hier');
      expect(dayLabel(DateTime(2026, 11, 3), now: now), '3 novembre');
      expect(dayLabel(DateTime(2026, 8, 30), now: now), '30 août');
      expect(dayLabel(DateTime(2025, 12, 31), now: now), '31 décembre 2025');
    });
    test('timeLabel', () {
      expect(timeLabel(DateTime(2026, 1, 1, 9, 5)), '09:05');
      expect(timeLabel(DateTime(2026, 1, 1, 23, 40)), '23:40');
    });
  });

  group('écran Historique', () {
    final now = DateTime(2026, 11, 22, 18, 0);

    HistoryStore seeded(List<HistoryEntry> list) => HistoryStore()..debugSet(list);

    testWidgets('vide : message et pas de corbeille', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_app(HistoryScreen(store: seeded(const []), now: now)));
      await tester.pumpAndSettle();

      expect(find.text('HISTORIQUE'), findsOneWidget);
      expect(find.text('Vos analyses'), findsOneWidget);
      expect(find.text('Aucune analyse pour le moment'), findsOneWidget);
      expect(find.bySemanticsLabel('Effacer l\'historique'), findsNothing);
    });

    testWidgets('liste groupée par jour, avec plante, heure et confiance', (tester) async {
      _phoneSize(tester);
      final store = seeded([
        _entry('1', DateTime(2026, 11, 22, 14, 37)),
        _entry('2', DateTime(2026, 11, 22, 9, 5),
            kind: DiagnosisKind.healthy, plant: 'Apple', top: const [('Apple___healthy', 0.99)]),
        _entry('3', DateTime(2026, 11, 21, 17, 0),
            kind: DiagnosisKind.uncertain, top: const [('Tomato___Late_blight', 0.41)]),
        _entry('4', DateTime(2026, 11, 3, 8, 30)),
      ]);
      await tester.pumpWidget(_app(HistoryScreen(store: store, now: now)));
      await tester.pumpAndSettle();

      expect(find.text('AUJOURD\'HUI'), findsOneWidget);
      expect(find.text('HIER'), findsOneWidget);
      expect(find.text('3 NOVEMBRE'), findsOneWidget);

      expect(find.text('Mildiou tardif'), findsNWidgets(2)); // lignes 1 et 4
      expect(find.text('Tomate · 14:37'), findsOneWidget);
      expect(find.text('Feuille saine'), findsOneWidget);
      expect(find.text('Pomme · 09:05'), findsOneWidget);
      expect(find.text('Diagnostic incertain'), findsOneWidget);
      expect(find.text(percentLabel(0.96)), findsNWidgets(2));
      expect(find.text(percentLabel(0.99)), findsOneWidget);
      expect(find.text(percentLabel(0.41)), findsOneWidget);
      expect(find.text('Maladie'), findsNWidgets(2));
      expect(find.text('Saine'), findsOneWidget);
      expect(find.text('Incertain'), findsOneWidget);
      expect(find.bySemanticsLabel('Effacer l\'historique'), findsOneWidget);
    });

    testWidgets('toucher une ligne rouvre le résultat, puis retour à la liste', (tester) async {
      _phoneSize(tester);
      final store = seeded([_entry('1', DateTime(2026, 11, 22, 14, 37))]);
      await tester.pumpWidget(_app(HistoryScreen(store: store, now: now)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mildiou tardif'));
      await tester.pumpAndSettle();

      expect(find.text('RÉSULTAT · TOMATE'), findsOneWidget);
      expect(find.text('Maladie détectée'), findsOneWidget);
      expect(find.text(percentLabel(0.96)), findsOneWidget);
      expect(find.textContaining('14:37'), findsOneWidget, reason: 'date de l\'analyse');
      expect(find.text('Nouvelle analyse'), findsNothing);

      await tester.tap(find.text('Retour à l\'historique'));
      await tester.pumpAndSettle();
      expect(find.text('Vos analyses'), findsOneWidget);
      expect(find.text('Mildiou tardif'), findsOneWidget);
    });

    testWidgets('glisser pour supprimer : confirmation, puis la ligne disparaît', (tester) async {
      _phoneSize(tester);
      final store = seeded([
        _entry('1', DateTime(2026, 11, 22, 14, 37)),
        _entry('2', DateTime(2026, 11, 22, 9, 5), kind: DiagnosisKind.healthy,
            top: const [('Tomato___healthy', 0.99)]),
      ]);
      await tester.pumpWidget(_app(HistoryScreen(store: store, now: now)));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Mildiou tardif'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer l\'analyse\u00a0?'), findsOneWidget);

      // Annuler : rien n'est supprimé.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(store.entries.value.length, 2);
      expect(find.text('Mildiou tardif'), findsOneWidget);

      await tester.drag(find.text('Mildiou tardif'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(store.entries.value.map((e) => e.id), ['2']);
      expect(find.text('Mildiou tardif'), findsNothing);
      expect(find.text('Feuille saine'), findsOneWidget);
    });

    testWidgets('corbeille : tout effacer après confirmation', (tester) async {
      _phoneSize(tester);
      final store = seeded([_entry('1', DateTime(2026, 11, 22, 14, 37))]);
      await tester.pumpWidget(_app(HistoryScreen(store: store, now: now)));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Effacer l\'historique'));
      await tester.pumpAndSettle();
      expect(find.text('Effacer l\'historique\u00a0?'), findsOneWidget);
      await tester.tap(find.text('Effacer'));
      await tester.pumpAndSettle();

      expect(store.entries.value, isEmpty);
      expect(find.text('Aucune analyse pour le moment'), findsOneWidget);
    });
  });

  group('accueil', () {
    testWidgets('le bouton Historique ouvre l\'historique', (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.pump(); // pas de pumpAndSettle : l'accueil a une animation continue

      expect(find.bySemanticsLabel('Historique'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Historique'));
      await tester.pumpAndSettle();
      expect(find.text('Vos analyses'), findsOneWidget);
    });
  });
}
