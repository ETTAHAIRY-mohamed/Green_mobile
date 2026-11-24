import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diagnosis.dart';
import '../models/history_entry.dart';

/// Nombre maximal d'analyses conservées (les plus anciennes sont supprimées).
const int kHistoryMaxEntries = 50;

/// Côté (en pixels) des vignettes enregistrées : assez net pour une ligne de
/// liste, assez léger (≈ 5 kB) pour tenir dans les préférences de l'app.
const int kThumbnailSize = 144;

/// Vignette carrée JPEG d'une photo : orientation EXIF → carré central →
/// [size]×[size]. Fonction pure (utilisée dans un Isolate et par les tests).
Uint8List makeThumbnailJpeg(
  Uint8List bytes, {
  int size = kThumbnailSize,
  int quality = 72,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Image illisible (format non pris en charge).');
  }
  final upright = img.bakeOrientation(decoded);
  final side = upright.width < upright.height ? upright.width : upright.height;
  final square = img.copyCrop(
    upright,
    x: (upright.width - side) ~/ 2,
    y: (upright.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = img.copyResize(
    square,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(small, quality: quality));
}

/// Historique des analyses, enregistré sur le téléphone (aucune connexion).
///
/// Stockage : une clé JSON pour la liste, une clé par vignette (base64).
/// La photo d'origine n'est jamais copiée ni envoyée nulle part.
class HistoryStore {
  HistoryStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// Instance partagée par l'application.
  static final HistoryStore instance = HistoryStore();

  static const String _listKey = 'plantcare.history.v1';
  static const String _thumbPrefix = 'plantcare.history.thumb.';

  final Future<SharedPreferences> Function() _prefs;

  /// Liste courante, de la plus récente à la plus ancienne.
  final ValueNotifier<List<HistoryEntry>> entries =
      ValueNotifier<List<HistoryEntry>>(const []);

  final Map<String, Uint8List> _thumbs = {};
  Future<void>? _loading;
  bool _loaded = false;
  Future<void> _writes = Future<void>.value();
  int _counter = 0;

  bool get isLoaded => _loaded;

  /// Vignette JPEG d'une entrée, si elle existe.
  Uint8List? thumbnail(String id) => _thumbs[id];

  /// Charge l'historique une seule fois (appels suivants : no-op).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(_listKey);
      final loaded = <HistoryEntry>[];
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            try {
              loaded.add(HistoryEntry.fromJson(Map<String, Object?>.from(item as Map)));
            } catch (e) {
              debugPrint('[PlantCare] entrée d\'historique ignorée : $e');
            }
          }
        }
      }
      loaded.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      for (final e in loaded) {
        final b64 = prefs.getString('$_thumbPrefix${e.id}');
        if (b64 != null) {
          try {
            _thumbs[e.id] = base64Decode(b64);
          } catch (_) {
            // Vignette corrompue : l'entrée reste, avec un visuel de remplacement.
          }
        }
      }
      entries.value = List.unmodifiable(loaded);
    } catch (e) {
      // JSON illisible ou stockage indisponible : on repart d'un historique vide.
      debugPrint('[PlantCare] historique illisible, remis à zéro : $e');
      entries.value = const [];
    }
    _loaded = true;
  }

  /// Enregistre une analyse. Ne lève jamais d'exception : un souci
  /// d'historique ne doit pas empêcher d'afficher le résultat.
  Future<HistoryEntry?> record({
    required Diagnosis diagnosis,
    required String imagePath,
    DateTime? now,
  }) async {
    try {
      await ensureLoaded();
      final when = now ?? DateTime.now();
      final id = '${when.millisecondsSinceEpoch}-${_counter++}';

      Uint8List? thumb;
      try {
        thumb = await Isolate.run(
          () => makeThumbnailJpeg(File(imagePath).readAsBytesSync()),
        );
      } catch (e) {
        debugPrint('[PlantCare] vignette impossible : $e');
      }

      final entry = HistoryEntry.fromDiagnosis(diagnosis, id: id, analyzedAt: when);
      if (thumb != null) _thumbs[id] = thumb;

      final next = [entry, ...entries.value];
      final dropped = next.length > kHistoryMaxEntries
          ? next.sublist(kHistoryMaxEntries)
          : const <HistoryEntry>[];
      final kept = next.length > kHistoryMaxEntries
          ? next.sublist(0, kHistoryMaxEntries)
          : next;
      for (final d in dropped) {
        _thumbs.remove(d.id);
      }
      entries.value = List.unmodifiable(kept);

      await _persist(
        addThumb: thumb == null ? null : (id, thumb),
        removeIds: [for (final d in dropped) d.id],
      );
      return entry;
    } catch (e, st) {
      debugPrint('[PlantCare] enregistrement de l\'historique impossible : $e\n$st');
      return null;
    }
  }

  /// Supprime une analyse.
  Future<void> remove(String id) async {
    await ensureLoaded();
    _thumbs.remove(id);
    entries.value = List.unmodifiable(
      entries.value.where((e) => e.id != id).toList(),
    );
    await _persist(removeIds: [id]);
  }

  /// Efface tout l'historique.
  Future<void> clear() async {
    await ensureLoaded();
    final ids = [for (final e in entries.value) e.id];
    _thumbs.clear();
    entries.value = const [];
    await _persist(removeIds: ids);
  }

  /// Écritures séquentielles : l'état en mémoire fait foi, chaque écriture
  /// reflète l'état au moment où elle s'exécute.
  Future<void> _persist({(String, Uint8List)? addThumb, List<String> removeIds = const []}) {
    return _writes = _writes.then((_) async {
      try {
        final prefs = await _prefs();
        if (addThumb != null) {
          await prefs.setString('$_thumbPrefix${addThumb.$1}', base64Encode(addThumb.$2));
        }
        for (final id in removeIds) {
          await prefs.remove('$_thumbPrefix$id');
        }
        await prefs.setString(
          _listKey,
          jsonEncode([for (final e in entries.value) e.toJson()]),
        );
      } catch (e) {
        debugPrint('[PlantCare] écriture de l\'historique impossible : $e');
      }
    });
  }

  /// Pour les tests d'écran : remplace le contenu sans toucher au stockage.
  @visibleForTesting
  void debugSet(List<HistoryEntry> list, {Map<String, Uint8List> thumbs = const {}}) {
    _thumbs
      ..clear()
      ..addAll(thumbs);
    entries.value = List.unmodifiable(list);
    _loading = Future<void>.value();
    _loaded = true;
  }
}
