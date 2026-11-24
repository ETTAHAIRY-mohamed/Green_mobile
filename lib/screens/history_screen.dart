import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/diagnosis.dart';
import '../models/history_entry.dart';
import '../services/history_store.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import '../utils/format.dart';
import 'result_screen.dart';

/// Historique des analyses : liste groupée par jour, enregistrée sur le
/// téléphone. Toucher une ligne rouvre le résultat ; glisser vers la gauche
/// (ou la corbeille) supprime, après confirmation.
class HistoryScreen extends StatefulWidget {
  HistoryScreen({super.key, HistoryStore? store, this.now})
      : store = store ?? HistoryStore.instance;

  final HistoryStore store;

  /// Date de référence (« Aujourd'hui », « Hier ») ; l'horloge par défaut.
  final DateTime? now;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.ensureLoaded();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: AppColors.borderSoft),
        ),
        title: Text(title, style: AppText.name.copyWith(fontSize: 25)),
        content: Text(message, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(fontFamily: kSans, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                fontFamily: kSans,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _clearAll() async {
    final ok = await _confirm(
      title: 'Effacer l\'historique\u00a0?',
      message: 'Toutes les analyses enregistrées sur ce téléphone seront '
          'supprimées. Cette action est définitive.',
      confirmLabel: 'Effacer',
    );
    if (ok) await widget.store.clear();
  }

  Future<bool> _confirmDelete() => _confirm(
        title: 'Supprimer l\'analyse\u00a0?',
        message: 'Elle sera retirée de l\'historique de ce téléphone.',
        confirmLabel: 'Supprimer',
      );

  void _open(HistoryEntry e) {
    final plant = e.plant;
    if (plant == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          plant: plant,
          imageBytes: widget.store.thumbnail(e.id),
          diagnosis: e.toDiagnosis(),
          analyzedAt: e.analyzedAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    return ValueListenableBuilder<List<HistoryEntry>>(
      valueListenable: widget.store.entries,
      builder: (context, entries, _) {
        return ScreenScaffold(
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
                  const Expanded(child: Overline('Historique')),
                  if (entries.isNotEmpty)
                    RoundIconButton(
                      icon: Icons.delete_outline,
                      semanticLabel: 'Effacer l\'historique',
                      onPressed: _clearAll,
                    ),
                ],
              ),
              const SizedBox(height: 26),
              const Text('Vos analyses', style: AppText.title),
              const SizedBox(height: 12),
              const Text(
                'Enregistrées uniquement sur ce téléphone.',
                style: AppText.body,
              ),
              const SizedBox(height: 26),
              if (!widget.store.isLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                )
              else if (entries.isEmpty)
                const _EmptyState()
              else
                ..._groups(entries, now),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _groups(List<HistoryEntry> entries, DateTime now) {
    final widgets = <Widget>[];
    String? currentDay;
    for (final e in entries) {
      final label = dayLabel(e.analyzedAt, now: now);
      if (label != currentDay) {
        currentDay = label;
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 10));
        widgets
          ..add(Overline(label))
          ..add(const SizedBox(height: 12));
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HistoryRow(
            key: ValueKey(e.id),
            entry: e,
            thumbnail: widget.store.thumbnail(e.id),
            onTap: () => _open(e),
            confirmDelete: _confirmDelete,
            onDeleted: () => widget.store.remove(e.id),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.illustrationBg,
              ),
              child: const Icon(Icons.history, size: 40, color: AppColors.gold),
            ),
            const SizedBox(height: 22),
            const Text(
              'Aucune analyse pour le moment',
              style: AppText.name,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Vos diagnostics apparaîtront ici après\nvotre première analyse.',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.entry,
    required this.thumbnail,
    required this.onTap,
    required this.confirmDelete,
    required this.onDeleted,
  });

  final HistoryEntry entry;
  final Uint8List? thumbnail;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (entry.kind) {
      DiagnosisKind.disease => ('Maladie', AppColors.diseaseBadgeText),
      DiagnosisKind.healthy => ('Saine', AppColors.healthyBadgeText),
      DiagnosisKind.uncertain => ('Incertain', AppColors.textSecondary),
    };
    final radius = BorderRadius.circular(AppSpacing.cardRadius);

    final card = Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.borderSoft),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.illustrationBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: thumbnail != null
                    ? Image.memory(
                        thumbnail!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
                      )
                    : const _ThumbPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.name.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.plantNameFr} · ${timeLabel(entry.analyzedAt)}',
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    percentLabel(entry.best.probability),
                    style: AppText.bodyStrong.copyWith(color: statusColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel,
                    style: AppText.caption.copyWith(fontSize: 12, color: statusColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: '${entry.title}, ${entry.plantNameFr}, '
          '${percentLabel(entry.best.probability)}, $statusLabel',
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Dismissible(
        key: ValueKey('dismiss-${entry.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => confirmDelete(),
        onDismissed: (_) => onDeleted(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.diseaseBadgeBg,
            borderRadius: radius,
          ),
          child: const Icon(Icons.delete_outline, color: AppColors.diseaseBadgeText),
        ),
        child: card,
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.eco_outlined, size: 26, color: AppColors.leafGreen),
    );
  }
}
