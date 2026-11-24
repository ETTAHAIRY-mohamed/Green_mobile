# PlantCare

> Guide détaillé des écrans, du calcul du diagnostic et de l'organisation du code : [`GUIDE_APPLICATION.md`](GUIDE_APPLICATION.md).

Application Flutter de **diagnostic des maladies de feuilles, hors ligne**, sur le téléphone.
Démonstrateur du modèle optimisé du projet *AI for Mobile and Embedded Systems* (Master 2 SIME, Rouen).

Parcours : choisir une plante → photo de feuille (galerie ou appareil photo avec cadre de visée) →
analyse locale → maladie, confiance, autres possibilités et conseils.
4 plantes (tomate, pomme de terre, pomme, pêche), 19 classes, aucune connexion requise.

## Prérequis

Testé avec Flutter 3.47.6 (Dart ≥ 3.13.5), Xcode 26.2 et CocoaPods 1.16.2. `flutter doctor` doit être au vert pour la
plateforme visée.

| Plateforme | Version minimale | Remarque |
|---|---|---|
| iOS | 15.0 | Xcode et CocoaPods requis |
| Android | `minSdk` 24 | SDK Android requis (build non vérifié, voir « Notes de plateforme ») |

Identifiant de l'application : `com.plantcare.plantcare` (nom affiché : PlantCare).

## Lancer l'application

```bash
flutter pub get
flutter run                       # appareil ou simulateur iOS/Android connecté
```

Le premier build iOS télécharge TensorFlow Lite via CocoaPods (quelques minutes).

### Installer sur un téléphone

```bash
flutter devices                              # repère l'identifiant du téléphone branché
flutter run --release -d <id_appareil>       # version release : latence réaliste
```

- **iPhone** : activer le *Mode développeur* (Réglages → Confidentialité et sécurité), puis choisir l'équipe de
  signature dans Xcode (`ios/Runner.xcworkspace` → Runner → Signing & Capabilities). Si iOS demande de faire
  confiance au certificat du développeur, l'autoriser dans les réglages du téléphone.
- **Android** : activer le débogage USB sur le téléphone (non vérifié ici).

## Le modèle

| Fichier (`assets/models/`) | Rôle |
|---|---|
| `plant_model.tflite` | modèle principal M5 (QAT int8) : entrée `[1,96,96,3]` **uint8** (pixels RGB 0–255 bruts), sortie `[1,19]` float32 |
| `plant_model_backup_float_input.tflite` | secours M3b : entrée float32 0–255 (non utilisé par l'application, voir les tests d'intégration) |
| `classes.json` | classes **dans l'ordre des sorties** (source de vérité, jamais codé en dur) |
| `model_info.json` | caractéristiques du modèle (variante, précision, taille), lues au chargement |

Le type d'entrée est **lu dans le modèle au chargement** (`lib/services/classifier.dart`) :
uint8 → pixels bruts, float32 → pixels 0–255 en float, int8 → quantification avec `scale`/`zeroPoint`.
Aucune normalisation côté application (elle est dans le modèle).

### Remplacer ou ajouter un modèle

1. Déposer le `.tflite` dans `assets/models/` et le déclarer dans `pubspec.yaml`.
2. Si les classes changent, remplacer `classes.json` (et `model_info.json`).
3. Pour essayer une autre variante dans les tests d'intégration (`integration_test/model_smoke_test.dart`),
   ajouter une ligne dans `lib/services/model_registry.dart`. L'application elle-même utilise toujours le modèle
   principal (`kMainModel`).

Pour le remplacement pur du modèle principal, il suffit de remplacer le fichier : l'entrée et la sortie restent identiques.

## Réglages

`lib/config.dart` : `kConfidenceThreshold` (0,60 — en dessous, l'écran « Diagnostic incertain » s'affiche),
durée minimale de l'écran d'analyse, paramètres du benchmark (utilisé par le test d'intégration).

## Pipeline d'inférence

photo → orientation EXIF → **carré central** → 96×96 RGB (dans un Isolate) → modèle →
filtre sur les classes de la plante choisie → renormalisation → top 3 → seuil de confiance.
Le cadre de visée de l'écran caméra correspond exactement au carré central conservé.

## Tests

```bash
flutter analyze
flutter test                                   # 46 tests : mapping FR, post-traitement, prétraitement, écrans, historique
```

Tests sur le **vrai modèle** (appareil ou simulateur) :

```bash
flutter test integration_test/model_smoke_test.dart -d <id_appareil>

# parité avec le notebook Python sur les 38 photos de test
flutter test integration_test/parity_test.dart -d <id_appareil> \
  --dart-define=PARITY_DIR=/chemin/du/dossier   # contient attendu.csv et images_test_plantcare/
```

**Latence** : l'écran de résultat affiche la durée de l'inférence de chaque analyse (« Analysé en X ms · M5 · int8 »).
Pour des chiffres réalistes, lire cette durée sur un vrai téléphone avec une version release
(`flutter run --release -d <id_appareil>`). Le test `integration_test/model_smoke_test.dart` affiche en plus la
moyenne, le minimum et le maximum sur 20 inférences (après 3 de chauffe), mais lancé avec `flutter test` il tourne en
**mode debug** (`flutter test` n'a pas d'option `--release`) : ses chiffres sont à prendre avec prudence.

## Historique des analyses

Le bouton horloge en haut de l'accueil ouvre l'historique : chaque analyse (maladie, saine ou incertaine)
est enregistrée **sur le téléphone** avec plante, date, confiance, 3 hypothèses et une petite vignette de la
photo (144 px, ~5 ko). Toucher une ligne rouvre le résultat ; glisser vers la gauche supprime une analyse, la
corbeille efface tout (confirmation demandée dans les deux cas).

- Stockage : `shared_preferences` (une clé JSON + une clé par vignette), code dans
  `lib/services/history_store.dart`. Aucune connexion, la photo d'origine n'est jamais copiée.
- Plafond : 50 analyses, les plus anciennes sont supprimées automatiquement (`kHistoryMaxEntries`).
- Données illisibles ou corrompues : l'historique repart vide (ou ignore l'entrée), sans planter l'app.
- Si l'enregistrement échoue (stockage indisponible), le résultat s'affiche quand même.

## Photos des plantes (accueil)

Les cartes de l'accueil affichent des photos détourées (`assets/images/plants/*.webp`, fond transparent).
Animations : entrée en cascade (carte puis fruit qui « tombe » avec un léger rebond), flottement continu
avec ombre au sol, réaction au toucher et transition **Hero** du fruit vers l'en-tête de l'écran photo.
Elles sont coupées si le système demande de réduire les animations. Pour changer une photo, remplacer le
fichier WebP (même nom) ; si elle est absente, l'illustration au trait est utilisée.

## Notes de plateforme

- **iOS : le modèle de secours M3b ne se charge pas.** Le plugin `tflite_flutter` 0.12.1 embarque
  TensorFlow Lite **2.12** sur iOS (pod `TensorFlowLiteSwift`), trop ancien pour M3b (« Unable to create
  interpreter »). Le modèle principal M5 fonctionne et c'est le seul utilisé par l'application ; les tests
  d'intégration signalent simplement que M3b n'est pas chargeable. Sur Android le plugin embarque LiteRT 1.4
  (non testé ici).
- **Projet sur un Bureau synchronisé iCloud** : `codesign` refuse `Flutter.framework` dès que le dossier
  `build/` se trouve dans le Bureau (« resource fork, Finder information… »). Ici `build` est un lien
  symbolique vers `~/Library/Caches/plantcare_app_build`. Ailleurs (dossier non synchronisé), c'est inutile.
  Si le lien est cassé : `mkdir -p ~/Library/Caches/plantcare_app_build && ln -s ~/Library/Caches/plantcare_app_build build`.
- **Redimensionnement** : la moyenne (aire) est la méthode qui reproduit Python (38/38 mêmes maladies sur
  les photos de test, écart moyen de confiance 1,5 point) ; un bilinéaire simple tombe à 28/38.
- **Android** : permissions et `minSdk 24` configurés, build non vérifié (licences du SDK à accepter :
  `flutter doctor --android-licenses`).

## Dépendances et licences

| Paquet | Usage |
|---|---|
| `tflite_flutter` | moteur d'inférence TensorFlow Lite |
| `image` | décodage et redimensionnement de la photo, vignettes |
| `image_picker` | choix d'une photo dans la galerie |
| `camera` | aperçu et prise de photo avec cadre de visée |
| `shared_preferences` | stockage local de l'historique |
| `cupertino_icons` | icônes |

Les polices **Cormorant Garamond** (titres) et **Inter** (texte) sont embarquées dans `assets/fonts/` : l'application ne
télécharge rien. Elles sont sous licence SIL Open Font License (textes dans `assets/fonts/OFL-*.txt`).

## Confidentialité et permissions

L'application n'envoie aucune donnée : le modèle, les classes, les textes et les polices sont embarqués, et le code ne
contient aucun appel réseau. Elle demande l'accès à l'appareil photo (prise de photo) et à la photothèque (choix d'une
photo) ; sur iOS, la galerie ne donne accès qu'à la photo choisie. Seule une petite vignette est conservée, dans
l'historique, sur le téléphone.

## Documents du projet (dossier parent)

Maquettes (`PlantCare – App diagnostic des plantes.pdf`), cahier de transmission (`PlantCare_handoff.md`),
présentation (`PlantCare_presentation.pptx`), notebooks, et le jeu de 38 photos de test (`images_test_plantcare/`
avec `attendu.csv`) utilisé par le test de parité.

## Limite connue

Le modèle est entraîné sur PlantVillage (photos de laboratoire). Une photo prise au champ (fond chargé,
lumière variable) est plus difficile : d'où les conseils de prise de vue, le cadre carré et le seuil
« diagnostic incertain ». Le résultat est **indicatif**.
