import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantcare/services/image_preprocessor.dart';

/// Pixel (x, y) d'une sortie `size × size × 3` en RGB.
List<int> _px(Uint8List rgb, int size, int x, int y) {
  final o = (y * size + x) * 3;
  return [rgb[o], rgb[o + 1], rgb[o + 2]];
}

void main() {
  const size = 96;

  test('sortie : size × size × 3 octets, quelle que soit l\'image', () {
    for (final (w, h) in [(300, 200), (200, 300), (96, 96), (1000, 640)]) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(10, 120, 30));
      final out = ImagePreprocessor.fromImage(image, size);
      expect(out.length, size * size * 3, reason: '${w}x$h');
    }
  });

  test('recadrage carré central (paysage)', () {
    // 200×100 : rouge à gauche, bleu à droite. Le carré central (100×100)
    // couvre x ∈ [50,150[ : moitié rouge puis moitié bleue.
    final image = img.Image(width: 200, height: 100);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 200; x++) {
        image.setPixelRgb(x, y, x < 100 ? 255 : 0, 0, x < 100 ? 0 : 255);
      }
    }
    final out = ImagePreprocessor.fromImage(image, size);
    expect(_px(out, size, 2, 48), [255, 0, 0]);
    expect(_px(out, size, 93, 48), [0, 0, 255]);
  });

  test('l\'orientation EXIF est corrigée avant le recadrage', () {
    // 120×60, rouge à gauche / vert à droite, EXIF = 6 (à afficher tourné de
    // 90° dans le sens horaire) : à l'écran, le rouge est EN HAUT.
    final image = img.Image(width: 120, height: 60);
    for (var y = 0; y < 60; y++) {
      for (var x = 0; x < 120; x++) {
        image.setPixelRgb(x, y, x < 60 ? 255 : 0, x < 60 ? 0 : 255, 0);
      }
    }
    image.exif.imageIfd.orientation = 6;
    final out = ImagePreprocessor.fromImage(image, size);
    expect(_px(out, size, 48, 2), [255, 0, 0], reason: 'haut = rouge');
    expect(_px(out, size, 48, 93), [0, 255, 0], reason: 'bas = vert');
  });

  test('une image avec canal alpha donne bien 3 canaux RGB', () {
    final image = img.Image(width: 64, height: 64, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(200, 100, 50, 255));
    final out = ImagePreprocessor.fromImage(image, size);
    expect(out.length, size * size * 3);
    expect(_px(out, size, 10, 10), [200, 100, 50]);
  });

  test('fromBytes : PNG valide décodé, octets invalides rejetés', () {
    final image = img.Image(width: 50, height: 80);
    img.fill(image, color: img.ColorRgb8(0, 200, 0));
    final png = Uint8List.fromList(img.encodePng(image));
    final out = ImagePreprocessor.fromBytes(png, size);
    expect(out.length, size * size * 3);
    expect(_px(out, size, 48, 48), [0, 200, 0]);

    expect(
      () => ImagePreprocessor.fromBytes(Uint8List.fromList([1, 2, 3, 4]), size),
      throwsFormatException,
    );
  });
}
