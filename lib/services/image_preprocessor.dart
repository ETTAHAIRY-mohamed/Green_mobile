import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prétraitement identique à celui de l'entraînement (handoff §6 bis, point 5) :
///
/// orientation EXIF → recadrage CARRÉ CENTRAL → redimensionnement exact à
/// la taille d'entrée du modèle → RGB (3 canaux, sans alpha).
///
/// Aucune normalisation ici : elle est dans le modèle.
class ImagePreprocessor {
  ImagePreprocessor._();

  /// Lit un fichier image et renvoie `size × size × 3` octets RGB.
  /// Le décodage d'une photo de téléphone (12 Mpx) est lourd : il tourne dans
  /// un Isolate pour ne pas figer l'interface.
  static Future<Uint8List> fromFile(
    String path,
    int size, {
    img.Interpolation interpolation = defaultInterpolation,
  }) {
    return Isolate.run(
      () => fromBytes(
        File(path).readAsBytesSync(),
        size,
        interpolation: interpolation,
      ),
    );
  }

  /// Méthode de redimensionnement par défaut : la moyenne (aire) convient à
  /// une forte réduction (photo de 12 Mpx → 96 px) sans repliement.
  static const img.Interpolation defaultInterpolation = img.Interpolation.average;

  /// Version pure (utilisée dans l'Isolate et par les tests).
  static Uint8List fromBytes(
    Uint8List bytes,
    int size, {
    img.Interpolation interpolation = defaultInterpolation,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Image illisible (format non pris en charge).');
    }
    return fromImage(decoded, size, interpolation: interpolation);
  }

  static Uint8List fromImage(
    img.Image source,
    int size, {
    img.Interpolation interpolation = defaultInterpolation,
  }) {
    // 1. Les photos de téléphone sont souvent stockées tournées (EXIF).
    final upright = img.bakeOrientation(source);

    // 2. Carré central.
    final side = math.min(upright.width, upright.height);
    final x = (upright.width - side) ~/ 2;
    final y = (upright.height - side) ~/ 2;
    final square = img.copyCrop(upright, x: x, y: y, width: side, height: side);

    // 3. Taille d'entrée du modèle (moyenne = adapté à une forte réduction).
    final resized = img.copyResize(
      square,
      width: size,
      height: size,
      interpolation: interpolation,
    );

    // 4. RGB 8 bits, sans canal alpha.
    final rgb = resized.convert(numChannels: 3, format: img.Format.uint8);
    final out = rgb.getBytes(order: img.ChannelOrder.rgb);
    assert(out.length == size * size * 3);
    return out;
  }
}
