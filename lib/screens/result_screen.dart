import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/diseases_fr.dart';
import '../data/plants.dart';
import '../models/diagnosis.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import '../utils/format.dart';
import 'upload_screen.dart' show PhotoTipRow, kPhotoTips;

/// Écrans 4 / 4b / 4c — Résultat : maladie détectée, feuille saine, ou
/// diagnostic incertain (confiance sous le seuil).
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.plant,
    this.imagePath,
    this.imageBytes,
    required this.diagnosis,
    this.analyzedAt,
  });

  final Plant plant;

  /// Photo analysée (analyse en direct).
  final String? imagePath;

  /// Vignette enregistrée (résultat rouvert depuis l'historique).
  final Uint8List? imageBytes;
  final Diagnosis diagnosis;

  /// Renseigné quand le résultat vient de l'historique : le bas de l'écran
  /// affiche alors la date et le bouton revient simplement à la liste.
  final DateTime? analyzedAt;

  bool get fromHistory => analyzedAt != null;

  @override
  Widget build(BuildContext context) {
    final kind = diagnosis.kind;
    final best = diagnosis.best;
    final info = best.info;
    final uncertain = kind == DiagnosisKind.uncertain;

    // Autres possibilités : pour un résultat net, les propositions 2 et 3 ;
    // pour un résultat incertain, les 3 hypothèses du modèle.
    final others = uncertain ? diagnosis.top : diagnosis.top.skip(1).toList();

    return ScreenScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GoldButton(
            label: fromHistory
                ? 'Retour à l\'historique'
                : uncertain
                    ? 'Reprendre la photo'
                    : 'Nouvelle analyse',
            onPressed: () {
              if (fromHistory || uncertain) {
                // Historique : retour à la liste. Sinon : écran 2 (même plante).
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Diagnostic indicatif, calculé hors ligne sur l\'appareil.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            fromHistory
                ? 'Analysé le ${dateLabel(analyzedAt!, now: DateTime.now())} à '
                    '${timeLabel(analyzedAt!)} · ${diagnosis.variantLabel}'
                : 'Analysé en ${msLabel(diagnosis.latencyMs)} · ${diagnosis.variantLabel}',
            style: AppText.caption.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Overline('Résultat · ${plant.nameFr}')),
              RoundIconButton(
                icon: Icons.close,
                semanticLabel: 'Fermer et revenir à l\'accueil',
                onPressed: () => fromHistory
                    ? Navigator.of(context).pop()
                    : Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Header(
            imagePath: imagePath,
            imageBytes: imageBytes,
            kind: kind,
            info: info,
          ),
          const SizedBox(height: 22),
          _ConfidenceCard(probability: best.probability, uncertain: uncertain),
          const SizedBox(height: 28),
          if (others.isNotEmpty) ...[
            Overline(uncertain ? 'Hypothèses du modèle' : 'Autres possibilités'),
            const SizedBox(height: 14),
            for (final p in others) _OtherRow(prediction: p),
            const SizedBox(height: 14),
          ],
          if (uncertain) ...[
            const Overline('Pour une meilleure photo'),
            const SizedBox(height: 14),
            for (final tip in kPhotoTips) PhotoTipRow(tip),
            const PhotoTipRow('Rapprochez-vous : la feuille doit remplir le cadre'),
          ] else ...[
            const Overline('Conseils'),
            const SizedBox(height: 12),
            Text(info.advice, style: AppText.bodySoft),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.imagePath,
    required this.imageBytes,
    required this.kind,
    required this.info,
  });

  final String? imagePath;
  final Uint8List? imageBytes;
  final DiagnosisKind kind;
  final DiseaseInfo info;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String? subtitle;
    final String badge;
    final Color badgeBg;
    final Color badgeFg;
    switch (kind) {
      case DiagnosisKind.disease:
        title = info.nameFr;
        subtitle = info.scientificName;
        badge = 'Maladie détectée';
        badgeBg = AppColors.diseaseBadgeBg;
        badgeFg = AppColors.diseaseBadgeText;
      case DiagnosisKind.healthy:
        title = 'Feuille saine';
        subtitle = null;
        badge = 'Aucune maladie détectée';
        badgeBg = AppColors.healthyBadgeBg;
        badgeFg = AppColors.healthyBadgeText;
      case DiagnosisKind.uncertain:
        title = 'Diagnostic incertain';
        subtitle = 'Le modèle n\'est pas sûr';
        badge = 'Confiance trop faible';
        badgeBg = AppColors.uncertainBadgeBg;
        badgeFg = AppColors.uncertainBadgeText;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSoft),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageBytes != null
              ? Image.memory(
                  imageBytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              : imagePath != null
                  ? Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.diseaseName),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppText.body.copyWith(
                    fontStyle: kind == DiagnosisKind.disease
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              StatusBadge(label: badge, background: badgeBg, foreground: badgeFg),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.probability, required this.uncertain});

  final double probability;
  final bool uncertain;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text('Confiance du modèle', style: AppText.body),
              ),
              Text(
                percentLabel(probability),
                style: AppText.percent.copyWith(
                  color: uncertain ? AppColors.textSecondary : AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProbabilityBar(
            value: probability,
            height: 8,
            color: uncertain ? AppColors.textSecondary : AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _OtherRow extends StatelessWidget {
  const _OtherRow({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prediction.info.nameFr,
                  style: AppText.bodyStrong,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                percentLabel(prediction.probability),
                style: AppText.body,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProbabilityBar(
            value: prediction.probability,
            height: 5,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
