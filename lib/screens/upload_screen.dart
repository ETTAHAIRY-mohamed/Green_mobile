import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/plants.dart';
import '../theme/app_theme.dart';
import '../theme/illustrations.dart';
import '../theme/plant_image.dart';
import '../theme/widgets.dart';
import 'analysis_screen.dart';
import 'camera_screen.dart';

/// Conseils de prise de vue (écran 2 et rappel de l'écran « incertain »).
const List<String> kPhotoTips = [
  'Une seule feuille, bien centrée',
  'Lumière naturelle, sans flash',
  'Face supérieure de la feuille, nette',
];

/// Écran 2 — Ajouter une photo (galerie ou appareil photo).
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, required this.plant});

  final Plant plant;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _photoPath;
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          content: Text(
            message,
            style: const TextStyle(fontFamily: kSans, color: AppColors.ivory),
          ),
        ),
      );
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (file != null && mounted) setState(() => _photoPath = file.path);
    } catch (_) {
      _snack('Impossible d\'ouvrir la galerie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      List<CameraDescription> cameras = const [];
      try {
        cameras = await availableCameras();
      } catch (_) {
        // Pas de caméra exploitable : on essaie le sélecteur système.
      }

      String? path;
      if (cameras.isNotEmpty) {
        if (!mounted) return;
        path = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CameraScreen(cameras: cameras),
          ),
        );
      } else {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        path = file?.path;
      }
      if (path != null && mounted) setState(() => _photoPath = path);
    } catch (_) {
      _snack('Appareil photo indisponible sur cet appareil. Utilisez la galerie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    final path = _photoPath;
    if (path == null) return;
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(plant: widget.plant, imagePath: path),
      ),
    );
    if (!mounted) return;
    // Retour de l'écran d'analyse/résultat : on repart d'une zone vide.
    setState(() => _photoPath = null);
    if (message != null && message.isNotEmpty) _snack(message);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoPath != null;
    return ScreenScaffold(
      bottom: GoldButton(
        label: 'Lancer l\'analyse',
        icon: Icons.arrow_forward,
        onPressed: hasPhoto ? _analyze : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.chevron_left,
                semanticLabel: 'Retour',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Overline('Étape 1 sur 2'),
                    const SizedBox(height: 4),
                    Text(widget.plant.nameFr, style: AppText.name),
                  ],
                ),
              ),
              Hero(
                tag: plantHeroTag(widget.plant),
                child: PlantImage(widget.plant, width: 60, height: 44),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text('Ajoutez une photo de la feuille', style: AppText.title),
          const SizedBox(height: 24),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AspectRatio(
              aspectRatio: hasPhoto ? 1 : 1.3,
              child: DashedBorderBox(
                child: hasPhoto
                    ? _PhotoPreview(path: _photoPath!)
                    : const _EmptyDropZone(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlineActionButton(
                  label: 'Galerie',
                  icon: Icons.image_outlined,
                  onPressed: _busy ? null : _pickFromGallery,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlineActionButton(
                  label: 'Appareil photo',
                  icon: Icons.photo_camera_outlined,
                  onPressed: _busy ? null : _takePhoto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (hasPhoto)
            // Photo choisie : l'aperçu prend la place des conseils.
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.crop_free, size: 20, color: AppColors.gold),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seul le carré central de la photo est analysé : la feuille '
                    'doit être dans le cadre doré.',
                    style: AppText.caption,
                  ),
                ),
              ],
            )
          else ...[
            const Overline('Pour un bon diagnostic'),
            const SizedBox(height: 14),
            for (final tip in kPhotoTips) PhotoTipRow(tip),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Ligne de conseil « ✓ … » (écran 2 et écran « incertain »).
class PhotoTipRow extends StatelessWidget {
  const PhotoTipRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check, size: 20, color: AppColors.gold),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppText.bodySoft.copyWith(height: 1.3))),
        ],
      ),
    );
  }
}

class _EmptyDropZone extends StatelessWidget {
  const _EmptyDropZone();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.illustrationBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const IllustrationView(
              Illustration.leaf,
              size: 44,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucune photo sélectionnée',
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.ivory,
            ),
          ),
          const SizedBox(height: 6),
          const Text('JPG ou PNG, une seule feuille', style: AppText.caption),
        ],
      ),
    );
  }
}

/// Aperçu carré : c'est exactement la zone (carré central) vue par le modèle.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.dropZoneRadius - 6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 900,
              errorBuilder: (_, _, _) => const Center(
                child: Text('Image illisible', style: AppText.caption),
              ),
            ),
            const CornerBrackets(inset: 14, length: 22, thickness: 2),
          ],
        ),
      ),
    );
  }
}
