# PlantCare — guide complet de l'application

Ce document explique **chaque écran**, **comment le diagnostic est calculé**, **où se trouve quoi dans le code**
et **comment lancer, tester et modifier** l'application. Pour une prise en main rapide, voir aussi `README.md`.

---

## 1. En bref

PlantCare est une application mobile (Flutter, iOS et Android) qui **diagnostique les maladies d'une feuille à
partir d'une photo, sans aucune connexion**. Le modèle d'intelligence artificielle est embarqué dans l'application
et tourne directement sur le téléphone.

| | |
|---|---|
| Plantes gérées | Tomate, Pomme de terre, Pomme, Pêche |
| Classes du modèle | 19 (15 maladies + 4 « feuille saine ») |
| Modèle principal | M5, MobileNetV2 alpha 0,35, quantifié int8, entrée 96×96, fichier de 649 048 octets (649 kB, soit 634 kio : c'est la valeur « 634 kB » de la présentation) |
| Précision du modèle principal | 95,15 % sur le jeu de test, 95,90 % une fois les résultats filtrés par plante (valeurs de `assets/models/model_info.json`) |
| Modèle de secours | M3b, version « dynamic range » à entrée float32, fichier de 567 488 octets (567 kB, soit 554 kio) (présent dans les fichiers, mais **non utilisé par l'application** ; seuls les tests d'intégration le chargent) |
| Réseau | Aucun : ni envoi de photo, ni compte, ni publicité |
| Stockage | Historique des analyses enregistré sur le téléphone uniquement |
| Résultat | **Indicatif** : ce n'est pas un avis agronomique |

---

## 2. Le parcours en un coup d'œil

```
┌──────────────┐   bouton horloge   ┌───────────────┐
│  1. Accueil  │ ─────────────────▶ │ 5. Historique │
└──────┬───────┘                    └───────┬───────┘
       │ choisir une plante                 │ toucher une ligne
       ▼                                    │ (résultat rouvert)
┌────────────────────┐   « Appareil photo »   ┌──────────────────┐
│ 2. Ajouter photo   │ ─────────────────────▶ │ 2b. Appareil     │
│ (galerie / caméra) │ ◀───────────────────── │     photo        │
└─────────┬──────────┘     photo prise        └──────────────────┘
          │ « Lancer l'analyse »
          ▼
┌────────────────────┐
│ 3. Analyse en cours│   (l'analyse est enregistrée dans l'historique)
└─────────┬──────────┘
          ▼
┌─────────────────────────────────────┐  « Nouvelle analyse »    → retour à l'accueil
│ 4. Résultat                         │  « Reprendre la photo »  → retour à l'écran 2
│ 4a maladie · 4b saine · 4c incertain│  « Retour à l'historique » (si ouvert depuis l'historique)
└─────────────────────────────────────┘
```

---

## 3. Les écrans, un par un

### Écran 1 — Accueil · `lib/screens/home_screen.dart`

**Rôle :** choisir la plante à examiner.

**Ce qu'on voit**
- En haut : le logo feuille et le titre **PlantCare**, puis un bouton rond **horloge** (l'historique).
- Un sur-titre « Diagnostic hors ligne », la question « Quelle plante examinons-nous ? » et une phrase d'explication.
- Une grille 2×2 de cartes : **Tomate**, **Pomme de terre**, **Pomme**, **Pêche**. Chaque carte montre une photo
  détourée du fruit ou du légume et le nom de la plante.
- En bas : une note de confidentialité (« Vos photos restent sur votre téléphone. L'analyse fonctionne sans connexion. »).

**Ce qu'on peut faire**
- Toucher une carte : ouvre l'écran 2 avec cette plante.
- Toucher le bouton horloge : ouvre l'historique (écran 5).

**Animations** (`_PlantCard`, `_Reveal`)
- À l'ouverture : le titre apparaît en fondu, les cartes montent l'une après l'autre (décalage de 110 ms) et le fruit
  « tombe » avec un léger rebond.
- En continu : chaque fruit flotte doucement, avec une légère rotation. Son ombre au sol rétrécit quand il monte.
- Au toucher : la carte s'enfonce et le fruit grossit.
- Au changement d'écran : le fruit « voyage » de la carte vers l'en-tête de l'écran 2 (transition Hero).
- Si le téléphone est réglé pour **réduire les animations**, tout s'affiche directement, sans mouvement.

**Photos :** `assets/images/plants/{tomato,potato,apple,peach}.webp` (fond transparent). Si une photo manque,
l'illustration au trait (`lib/theme/illustrations.dart`) la remplace.

---

### Écran 2 — Ajouter une photo · `lib/screens/upload_screen.dart`

**Rôle :** fournir la photo de la feuille. Le sur-titre indique « Étape 1 sur 2 », avec le nom de la plante et son
fruit à droite.

**Ce qu'on voit**
- Une grande zone en pointillés : « Aucune photo sélectionnée — JPG ou PNG, une seule feuille ».
- Deux boutons : **Galerie** et **Appareil photo**.
- Trois conseils (« Pour un bon diagnostic ») : une seule feuille bien centrée, lumière naturelle sans flash, face
  supérieure de la feuille nette.
- Le bouton **Lancer l'analyse**, grisé tant qu'aucune photo n'est choisie.

**Une fois la photo choisie**
- La zone affiche la photo dans un cadre carré avec des coins dorés.
- Un rappel s'affiche : « Seul le carré central de la photo est analysé : la feuille doit être dans le cadre doré. »
- Le bouton **Lancer l'analyse** devient actif.

**Cas particuliers**
- La galerie réduit les très grandes photos à 2048 px maximum avant de les transmettre.
- Si aucune caméra n'est exploitable, le bouton « Appareil photo » ouvre le sélecteur système à la place.
- Messages d'erreur (bandeau en bas) : « Impossible d'ouvrir la galerie. », « Appareil photo indisponible sur cet
  appareil. Utilisez la galerie. »
- Si l'analyse échoue, on revient ici avec l'un de ces messages : « Cette image n'a pas pu être lue. Essayez une
  photo JPG ou PNG. » ou « L'analyse a échoué. Reprenez la photo et réessayez. » La zone est alors vidée.

---

### Écran 2b — Appareil photo · `lib/screens/camera_screen.dart`

**Rôle :** prendre la photo directement dans l'application, avec un cadre de visée.

**Ce qu'on voit**
- Un écran plein format avec le sur-titre « Appareil photo » et un bouton pour fermer.
- Le message « Placez la feuille dans le cadre ».
- L'aperçu de la caméra avec un **cadre carré** : c'est exactement la zone qui sera analysée (le carré central de la
  photo finale). Les bandes hors cadre sont assombries : elles seront rognées.
- Un bouton rond de déclenchement (« Prendre la photo »).

**Cas particuliers**
- Accès à la caméra refusé : « L'accès à l'appareil photo est refusé. Autorisez-le dans les réglages du téléphone, ou
  utilisez la galerie. »
- Autre échec : « L'appareil photo n'a pas pu démarrer. » ou « La photo n'a pas pu être prise. »
- Si l'application passe en arrière-plan, la caméra est libérée puis relancée au retour.
- Le simulateur iOS n'a pas de caméra : cet écran ne se teste que sur un vrai téléphone.

---

### Écran 3 — Analyse en cours · `lib/screens/analysis_screen.dart`

**Rôle :** faire le calcul et faire patienter un instant.

**Ce qu'on voit**
- Le sur-titre « Étape 2 sur 2 » et le nom de la plante.
- La photo dans un cadre carré, parcourue par une **ligne de balayage animée**.
- « Analyse en cours… » et « Le modèle fonctionne directement sur votre téléphone. »
- Trois étapes qui se cochent : **Préparation de l'image**, **Identification de la maladie**, **Résultat et conseils**.

**Ce qui se passe vraiment**
1. La photo est préparée (voir section 4) dans un processus séparé pour ne pas figer l'écran.
2. Le modèle calcule les probabilités (quelques millisecondes).
3. L'écran reste au moins **1,2 seconde** (`kMinAnalysisDuration`) : le calcul réel est trop rapide pour être perçu.
4. Le résultat s'affiche en fondu, et l'analyse est **enregistrée dans l'historique en arrière-plan**. Si
   l'enregistrement échoue, le résultat s'affiche quand même.

---

### Écran 4 — Résultat · `lib/screens/result_screen.dart`

Un même écran, trois présentations selon la confiance du modèle.

**Éléments communs**
- Le sur-titre « Résultat · » suivi de la plante, et un bouton **×** qui ramène à l'accueil.
- La photo analysée en miniature carrée à gauche.
- Une carte **Confiance du modèle** : pourcentage en grand et barre de progression. Une valeur non nulle mais
  inférieure à 0,5 % s'affiche « < 1 % ».
- En bas : un bouton principal, la mention « Diagnostic indicatif, calculé hors ligne sur l'appareil. » et la ligne
  « Analysé en X ms · variante du modèle ». Cette durée est celle de l'**inférence seule** (le prétraitement de la
  photo est exclu) : c'est la latence de cette analyse sur le téléphone.

| | **4a — Maladie détectée** | **4b — Feuille saine** | **4c — Diagnostic incertain** |
|---|---|---|---|
| Quand | meilleure classe ≥ 60 % et ce n'est pas une classe « healthy » | meilleure classe ≥ 60 % et c'est « healthy » | meilleure classe < 60 % |
| Titre | nom français de la maladie, nom scientifique en italique | « Feuille saine » | « Diagnostic incertain », « Le modèle n'est pas sûr » |
| Pastille | « Maladie détectée » (ambre) | « Aucune maladie détectée » (vert) | « Confiance trop faible » (gris) |
| Suite | « Autres possibilités » : les 2e et 3e classes avec leurs barres, puis **Conseils** | « Autres possibilités », puis **Conseils** | « Hypothèses du modèle » : les 3 premières classes, puis « Pour une meilleure photo » (conseils de prise de vue) |
| Bouton | **Nouvelle analyse** (retour accueil) | **Nouvelle analyse** | **Reprendre la photo** (retour écran 2, même plante) |

Par prudence, **aucun conseil sanitaire n'est donné** quand le diagnostic est incertain. Le seuil de 60 % se règle
dans `lib/config.dart` (`kConfidenceThreshold`).

**Résultat rouvert depuis l'historique :** même présentation, mais le bouton devient **Retour à l'historique**, le
× revient à la liste, et la dernière ligne indique « Analysé le 22 novembre à 16:50 · M5 · int8 » au lieu de la durée.

---

### Écran 5 — Historique · `lib/screens/history_screen.dart`

**Rôle :** retrouver les analyses passées. On l'ouvre avec le bouton horloge de l'accueil.

**Ce qu'on voit**
- « Vos analyses » et « Enregistrées uniquement sur ce téléphone. »
- Les analyses **regroupées par jour** : Aujourd'hui, Hier, puis la date (« 3 novembre », avec l'année si elle diffère).
- Une ligne par analyse : vignette de la photo, titre (maladie, « Feuille saine » ou « Diagnostic incertain »), plante
  et heure, puis à droite la confiance et un statut (**Maladie** en ambre, **Saine** en vert, **Incertain** en gris).
- Tant que rien n'est enregistré : « Aucune analyse pour le moment ».

**Ce qu'on peut faire**
- **Toucher une ligne** : rouvre le résultat complet (écran 4).
- **Glisser une ligne vers la gauche** : supprime cette analyse, après la question « Supprimer l'analyse ? ».
- **Corbeille en haut à droite** (visible seulement s'il y a des analyses) : efface tout, après « Effacer l'historique ? ».

**Comment c'est stocké** · `lib/services/history_store.dart`
- Pour chaque analyse : plante, nature du résultat, jusqu'à 3 hypothèses, durée, variante du modèle, date, et une
  **vignette JPEG de 144 px** (environ 5 kB). La photo d'origine n'est jamais copiée.
- Stockage local via le plugin `shared_preferences` : une clé pour la liste, une clé par vignette.
- **50 analyses maximum** (`kHistoryMaxEntries`) : les plus anciennes sont supprimées automatiquement.
- Données illisibles ou corrompues : l'historique repart vide (ou ignore l'entrée abîmée), sans planter l'application.

---

## 4. Comment le diagnostic est calculé

```
photo ─▶ ① orientation EXIF ─▶ ② carré central ─▶ ③ 96×96 RGB ─▶ ④ modèle ─▶ 19 probabilités
                                                                                      │
        résultat ◀─ ⑧ seuil 60 % ◀─ ⑦ top 3 ◀─ ⑥ renormalisation ◀─ ⑤ classes de la plante choisie
```

1. **Orientation EXIF** : les photos de téléphone sont souvent stockées tournées ; on les remet à l'endroit.
2. **Carré central** : on garde le plus grand carré au centre de la photo (c'est ce que montre le cadre doré).
3. **Réduction à 96×96** par moyenne des pixels (adaptée à une forte réduction), en RGB sans transparence.
   Aucune normalisation n'est faite par l'application : elle est incluse dans le modèle.
4. **Modèle** : le fichier `.tflite` renvoie 19 probabilités, dans l'ordre de `classes.json`.
5. **Filtre par plante** : on ne garde que les classes de la plante choisie à l'écran 1 (par exemple, 10 classes pour
   la tomate).
6. **Renormalisation** : ces probabilités sont ramenées à une somme de 100 %.
7. **Top 3** : les trois classes les plus probables.
8. **Seuil de confiance (60 %)** : en dessous, le résultat est « incertain » ; au-dessus, c'est « saine » ou « maladie ».

> Exemple : photo de tomate avec les probabilités filtrées Mildiou 41 %, Alternariose 33 %, Saine 26 %. Le meilleur
> score (41 %) est sous 60 % : l'écran 4c « Diagnostic incertain » s'affiche avec ces trois hypothèses.

Le type d'entrée du modèle est **lu dans le fichier au chargement**, ce qui permet de remplacer le modèle sans toucher
au code (uint8, float32 ou int8 sont gérés). Le calcul est dans `lib/services/classifier.dart` ; le prétraitement dans
`image_preprocessor.dart` ; le filtre, le tri et le seuil dans `postprocess.dart`.

---

## 5. Les plantes et les 19 classes

Source de vérité : `assets/models/classes.json` (l'ordre des classes est celui des sorties du modèle, jamais codé en
dur). Les noms français, noms scientifiques et conseils viennent de `lib/data/diseases_fr.dart`.

| Plante | Classe du modèle | Nom affiché | Nom scientifique |
|---|---|---|---|
| **Tomate** | `Tomato___Bacterial_spot` | Tache bactérienne | *Xanthomonas* spp. |
| | `Tomato___Early_blight` | Alternariose | *Alternaria solani* |
| | `Tomato___Late_blight` | Mildiou tardif | *Phytophthora infestans* |
| | `Tomato___Leaf_Mold` | Cladosporiose | *Passalora fulva* |
| | `Tomato___Septoria_leaf_spot` | Septoriose | *Septoria lycopersici* |
| | `Tomato___Spider_mites Two-spotted_spider_mite` | Acariens (tétranyque tisserand) | *Tetranychus urticae* |
| | `Tomato___Target_Spot` | Corynesporiose (tache cible) | *Corynespora cassiicola* |
| | `Tomato___Tomato_Yellow_Leaf_Curl_Virus` | Virus des feuilles jaunes en cuillère (TYLCV) | *Begomovirus* |
| | `Tomato___Tomato_mosaic_virus` | Virus de la mosaïque de la tomate (ToMV) | *Tobamovirus* |
| | `Tomato___healthy` | Feuille saine | |
| **Pomme de terre** | `Potato___Early_blight` | Alternariose | *Alternaria solani* |
| | `Potato___Late_blight` | Mildiou tardif | *Phytophthora infestans* |
| | `Potato___healthy` | Feuille saine | |
| **Pomme** | `Apple___Apple_scab` | Tavelure | *Venturia inaequalis* |
| | `Apple___Black_rot` | Pourriture noire | *Botryosphaeria obtusa* |
| | `Apple___Cedar_apple_rust` | Rouille grillagée du pommier | *Gymnosporangium juniperi-virginianae* |
| | `Apple___healthy` | Feuille saine | |
| **Pêche** | `Peach___Bacterial_spot` | Tache bactérienne | *Xanthomonas arboricola* pv. *pruni* |
| | `Peach___healthy` | Feuille saine | |

Total : 9 + 2 + 3 + 1 = **15 maladies**, plus 4 classes saines = 19 classes.

---

## 6. Confidentialité et permissions

- **Aucun réseau** : le code ne contient aucun appel réseau, l'application n'envoie rien. Le modèle, les classes, les
  textes et les polices sont embarqués. (La permission Android `INTERNET` n'existe que dans les builds de
  développement `debug` et `profile`, pour l'outil Flutter ; elle est absente de la version release.)
- **Photos** : analysées sur le téléphone. Seule une petite vignette est gardée, dans l'historique.
- **Permissions demandées** : appareil photo (`NSCameraUsageDescription` sur iOS, `CAMERA` sur Android) et
  photothèque (`NSPhotoLibraryUsageDescription` sur iOS). Sur iOS, la galerie n'expose que la photo choisie.
- **Android** : version minimale 24 (nécessaire à la caméra et au moteur d'inférence).

---

## 7. Organisation du code

```
plantcare_app/
├── assets/
│   ├── models/        plant_model.tflite · plant_model_backup_float_input.tflite · classes.json · model_info.json
│   ├── images/plants/ tomato.webp · potato.webp · apple.webp · peach.webp
│   └── fonts/         Cormorant Garamond (titres) · Inter (texte), avec licences
├── lib/
│   ├── main.dart            démarrage : charge le modèle une fois, puis affiche l'accueil
│   ├── config.dart          seuil de confiance, durée mini d'analyse, paramètres du benchmark (tests)
│   ├── screens/             home · upload · camera · analysis · result · history
│   ├── services/            classifier (moteur TFLite) · image_preprocessor · postprocess ·
│   │                        class_map · model_registry · history_store
│   ├── models/              diagnosis (résultat) · history_entry (analyse enregistrée)
│   ├── data/                plants (les 4 plantes) · diseases_fr (noms, conseils)
│   ├── theme/               app_theme (couleurs, textes) · widgets · illustrations · plant_image · routes
│   └── utils/format.dart    pourcentages, durées et dates à la française
├── test/                    tests unitaires et d'écrans
├── integration_test/        tests sur le vrai modèle (fumée, parité avec Python)
├── README.md                prise en main rapide
└── GUIDE_APPLICATION.md     ce document
```

**Charte graphique « herbier de nuit »** : fond vert très sombre, accents dorés, titres en serif (Cormorant Garamond),
texte en Inter. Les couleurs et styles sont centralisés dans `lib/theme/app_theme.dart`.

---

## 8. Modifier l'application

| Je veux… | Je modifie… |
|---|---|
| Changer le seuil « diagnostic incertain » | `kConfidenceThreshold` dans `lib/config.dart` (0,60 par défaut) |
| Allonger ou raccourcir l'écran d'analyse | `kMinAnalysisDuration` dans `lib/config.dart` |
| Changer les valeurs par défaut du benchmark de latence (utilisé par les tests d'intégration) | `kBenchmarkWarmup` et `kBenchmarkRuns` dans `lib/config.dart` |
| Remplacer le modèle principal | remplacer `assets/models/plant_model.tflite` (même entrée/sortie : rien d'autre à faire) |
| Changer les classes du modèle | remplacer `classes.json` et `model_info.json`, puis compléter `lib/data/diseases_fr.dart` |
| Essayer une autre variante de modèle dans les tests d'intégration | déposer le `.tflite`, le déclarer dans `pubspec.yaml`, ajouter une ligne dans `lib/services/model_registry.dart` (l'application utilise toujours `kMainModel`) |
| Changer une photo de plante | remplacer le fichier `.webp` de même nom dans `assets/images/plants/` |
| Modifier un conseil ou un nom de maladie | `lib/data/diseases_fr.dart` |
| Changer la taille de l'historique | `kHistoryMaxEntries` (et `kThumbnailSize`) dans `lib/services/history_store.dart` |

---

## 9. Lancer, tester, installer

```bash
flutter pub get
flutter run                                  # appareil ou simulateur connecté
flutter run --release -d <id_appareil>       # version release (latence réaliste) sur un téléphone
```

`flutter devices` donne l'identifiant des appareils. Le premier build iOS télécharge TensorFlow Lite via CocoaPods
(quelques minutes).

```bash
flutter analyze                              # doit afficher « No issues found »
flutter test                                 # 46 tests, sans appareil
```

Les 46 tests :

| Fichier | Nombre | Ce qu'il vérifie |
|---|---|---|
| `test/catalog_test.dart` | 7 | cohérence de `classes.json` (19 classes, 4 plantes), une entrée française par classe, noms uniques, variantes de graphie, classe inconnue, comptage des maladies par plante (9, 2, 3, 1) |
| `test/postprocess_test.dart` | 10 | filtre par plante, renormalisation, top 3 trié, seuil (et seuil réglable), classe « healthy », plante à 2 classes, probabilités hors plante, somme nulle, erreurs, conservation des 19 probabilités brutes |
| `test/preprocessor_test.dart` | 5 | sortie de taille × taille × 3 octets, carré central, orientation EXIF, canal alpha retiré, image illisible rejetée |
| `test/widget_test.dart` | 5 | accueil, écran photo, résultats 4a, 4b, 4c |
| `test/history_test.dart` | 19 | stockage (sauvegarde, rechargement, plafond, suppression, données corrompues), vignette, dates, écran historique |

Tests sur le **vrai modèle**, avec un appareil ou un simulateur :

```bash
flutter test integration_test/model_smoke_test.dart -d <id_appareil>
flutter test integration_test/parity_test.dart -d <id_appareil> \
  --dart-define=PARITY_DIR=/chemin/du/dossier      # dossier contenant attendu.csv et images_test_plantcare/
```

Le test `model_smoke_test` affiche aussi la **latence** sur l'appareil (moyenne, minimum et maximum sur 20 inférences
après 3 de chauffe). Lancé avec `flutter test`, il tourne en **mode debug** (cette commande n'a pas d'option
`--release`) : ses chiffres sont à prendre avec prudence. Pour une latence réaliste, lire la durée affichée sur
l'écran de résultat avec une version release (`flutter run --release -d <id_appareil>`).

Le test de **parité** compare l'application au notebook Python sur les 38 photos de test : les **38 maladies sont
identiques** à `attendu.csv`, avec un écart moyen de confiance d'environ 1,5 point (le plus gros écart, d'environ 16
points, concerne deux photos de tomate). La réduction par moyenne est ce qui permet de coller à Python : un simple
bilinéaire tomberait à 28 bonnes réponses sur 38.

**Bon à savoir pour construire sur ce Mac :** le Bureau est synchronisé avec iCloud, ce qui fait échouer la signature
iOS dès que le dossier `build/` s'y trouve. Ici `build` est un lien symbolique vers `~/Library/Caches/plantcare_app_build`.
S'il est cassé :

```bash
mkdir -p ~/Library/Caches/plantcare_app_build && ln -s ~/Library/Caches/plantcare_app_build build
```

---

## 10. Limites connues

- **Données d'entraînement** : le modèle est entraîné sur PlantVillage (photos de laboratoire sur fond uni). Une photo
  prise au champ, avec un fond chargé ou une lumière variable, est plus difficile. D'où les conseils de prise de vue,
  le cadre carré et le seuil « incertain ». Le résultat reste **indicatif**.
- **Modèle de secours M3b sur iOS** : il ne se charge pas, car le plugin `tflite_flutter` embarque TensorFlow Lite 2.12,
  trop ancien. Le modèle principal M5 fonctionne et c'est le seul utilisé par l'application ; les tests d'intégration
  signalent simplement que M3b n'est pas chargeable.
- **Android** : permissions et version minimale sont configurées, mais le build n'a pas été vérifié (il faut d'abord
  accepter les licences du SDK avec `flutter doctor --android-licenses`).
- **Appareil photo** : testable uniquement sur un vrai téléphone (le simulateur n'a pas de caméra).
- **Latence** : les mesures faites sur simulateur ne représentent pas un téléphone. Pour le rapport, mesurer sur le
  téléphone avec une version release (`flutter run --release`) et lire la durée affichée sur l'écran de résultat ; le
  test `model_smoke_test` tourne en mode debug.
- **Historique** : limité à 50 analyses et stocké localement ; désinstaller l'application l'efface.
