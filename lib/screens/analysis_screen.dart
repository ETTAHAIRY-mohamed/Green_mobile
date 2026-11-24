import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../data/plants.dart';
import '../services/classifier.dart';
import '../services/history_store.dart';
import '../services/image_preprocessor.dart';
import '../theme/app_theme.dart';
import '../theme/routes.dart';
import '../theme/widgets.dart';
import 'result_screen.dart';

/// Écran 3 — Analyse en cours.
///
/// L'inférence réelle (prétraitement + modèle) tourne ici ; l'écran reste au
/// moins [kMinAnalysisDuration] pour l'effet visuel, puis passe au résultat.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.plant, required this.imagePath});

  final Plant plant;
  final String imagePath;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  /// 0 = préparation, 1 = identification, 2 = résultat et conseils.
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final started = Stopwatch()..start();
    try {
      final classifier = Classifier.instance;

      // 1. Préparation de l'image (EXIF, carré central, 96×96, RGB).
      final rgb = await ImagePreprocessor.fromFile(
        widget.imagePath,
        classifier.inputSize,
      );
      await _atLeast(started, kMinAnalysisDuration * 0.35);
      if (!mounted) return;
      setState(() => _stage = 1);

      // 2. Identification de la maladie (inférence chronométrée).
      final diagnosis = await classifier.diagnoseRgb(
        plant: widget.plant.key,
        rgb: rgb,
      );
      await _atLeast(started, kMinAnalysisDuration * 0.85);
      if (!mounted) return;
      setState(() => _stage = 2);

      // 3. Résultat et conseils.
      await _atLeast(started, kMinAnalysisDuration);
      if (!mounted) return;

      // Historique : enregistrement en arrière-plan (ne bloque ni ne fait
      // échouer l'affichage du résultat).
      unawaited(
        HistoryStore.instance.record(
          diagnosis: diagnosis,
          imagePath: widget.imagePath,
        ),
      );
      Navigator.of(context).pushReplacement(
        fadeRoute<String>(
          ResultScreen(
            plant: widget.plant,
            imagePath: widget.imagePath,
            diagnosis: diagnosis,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[PlantCare] analyse échouée : $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pop(
        e is FormatException
            ? 'Cette image n\'a pas pu être lue. Essayez une photo JPG ou PNG.'
            : 'L\'analyse a échoué. Reprenez la photo et réessayez.',
      );
    }
  }

  Future<void> _atLeast(Stopwatch started, Duration target) async {
    final remaining = target - started.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Overline('Étape 2 sur 2'),
          const SizedBox(height: 4),
          Text(widget.plant.nameFr, style: AppText.name),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1,
            child: _ScanFrame(imagePath: widget.imagePath, animation: _scan),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'Analyse en cours…',
              style: AppText.title,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Le modèle fonctionne directement sur votre téléphone.',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          _Steps(stage: _stage),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.imagePath, required this.animation});

  final String imagePath;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // BoxFit.cover dans un carré = exactement le carré central du modèle.
          Opacity(
            opacity: 0.8,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              cacheWidth: 900,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const CornerBrackets(inset: 16, length: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              const inset = 22.0;
              final travel = constraints.maxHeight - inset * 2;
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(animation.value);
                  return Stack(
                    children: [
                      Positioned(
                        left: inset,
                        right: inset,
                        top: inset + travel * t,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.55),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.stage});

  final int stage;

  static const _labels = [
    'Préparation de l\'image',
    'Identification de la maladie',
    'Résultat et conseils',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _StepRow(label: _labels[i], state: _stateOf(i)),
          ],
        ],
      ),
    );
  }

  _StepState _stateOf(int i) {
    if (i < stage) return _StepState.done;
    if (i == stage) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final pending = state == _StepState.pending;
    return Row(
      children: [
        _Marker(state: state),
        const SizedBox(width: 16),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 15,
              color: pending ? AppColors.textSecondary : AppColors.ivory,
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.state});

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    switch (state) {
      case _StepState.done:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 16, color: AppColors.onGold),
        );
      case _StepState.active:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          ),
        );
      case _StepState.pending:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.track, width: 2),
          ),
        );
    }
  }
}
