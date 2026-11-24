import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/widgets.dart';

/// Écran caméra avec cadre de visée carré (handoff §6 bis, point 1).
///
/// Le cadre carré est exactement la zone conservée par le prétraitement
/// (recadrage au carré central de la photo) : ce qui est dans le cadre est ce
/// que voit le modèle. Renvoie le chemin de la photo prise (`Navigator.pop`).
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  CameraDescription get _description => widget.cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      );

  Future<void> _initialize() async {
    final controller = CameraController(
      _description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off); // « lumière naturelle, sans flash »
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
      return;
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() => _error = 'L\'appareil photo n\'a pas pu démarrer.');
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _error = null;
    });
  }

  String _messageFor(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'L\'accès à l\'appareil photo est refusé. Autorisez-le dans les '
            'réglages du téléphone, ou utilisez la galerie.';
      default:
        return 'L\'appareil photo n\'a pas pu démarrer.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      setState(() => _controller = null);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(file.path);
    } on CameraException {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La photo n\'a pas pu être prise.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenSide,
              top + 12,
              AppSpacing.screenSide,
              12,
            ),
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.close,
                  semanticLabel: 'Fermer l\'appareil photo',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 16),
                const Overline('Appareil photo'),
              ],
            ),
          ),
          Expanded(child: Center(child: _buildPreview())),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Placez la feuille dans le cadre',
                  style: AppText.bodySoft,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                _ShutterButton(
                  enabled: _controller != null && !_capturing,
                  onPressed: _shoot,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 40, color: AppColors.gold),
            const SizedBox(height: 16),
            Text(_error!, style: AppText.body, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Aperçu portrait (rapport hauteur/largeur = aspectRatio du capteur,
        // exprimé en paysage), réduit pour tenir dans l'espace disponible.
        // Le carré de visée a pour côté la largeur de l'aperçu : c'est le
        // carré central de la photo finale.
        final ratio = controller.value.aspectRatio;
        final width = math.min(constraints.maxWidth, constraints.maxHeight / ratio);
        final previewHeight = width * ratio;
        final band = (previewHeight - width) / 2;
        return SizedBox(
          width: width,
          height: previewHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(child: CameraPreview(controller)),
              // Zones hors cadre assombries : elles seront rognées.
              if (band > 0) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: band,
                  child: const ColoredBox(color: Color(0x99000000)),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: band,
                  child: const ColoredBox(color: Color(0x99000000)),
                ),
              ],
              Positioned(
                top: band > 0 ? band : 0,
                left: 0,
                right: 0,
                height: width,
                child: const CornerBrackets(inset: 24, length: 34, thickness: 3),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Prendre la photo',
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
