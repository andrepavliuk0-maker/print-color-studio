import 'dart:typed_data';

import 'package:image/image.dart' as img;

class CmykProcessor {
  static Uint8List? apply(
    Uint8List sourceBytes, {
    required double cyan,
    required double magenta,
    required double yellow,
    required double black,
  }) {
    final source = img.decodeImage(sourceBytes);

    if (source == null) {
      return null;
    }

    final result = img.Image.from(source);

    for (final pixel in result) {
      final r = pixel.r / 255.0;
      final g = pixel.g / 255.0;
      final b = pixel.b / 255.0;

      // RGB → CMYK
      final k = 1.0 - _max3(r, g, b);

      double c = 0;
      double m = 0;
      double y = 0;

      if (k < 1.0) {
        c = (1.0 - r - k) / (1.0 - k);
        m = (1.0 - g - k) / (1.0 - k);
        y = (1.0 - b - k) / (1.0 - k);
      }

      // Коррекция каналов.
      c = _adjust(c, cyan);
      m = _adjust(m, magenta);
      y = _adjust(y, yellow);
      final adjustedK = _adjust(k, black);

      // CMYK → RGB
      final newR = 255.0 * (1.0 - c) * (1.0 - adjustedK);
      final newG = 255.0 * (1.0 - m) * (1.0 - adjustedK);
      final newB = 255.0 * (1.0 - y) * (1.0 - adjustedK);

      pixel
        ..r = _clamp(newR)
        ..g = _clamp(newG)
        ..b = _clamp(newB);
    }

    return Uint8List.fromList(
      img.encodePng(result),
    );
  }

  static double _adjust(double value, double correction) {
    final amount = correction / 100.0;

    // Положительное значение увеличивает количество данного
    // печатного канала, отрицательное уменьшает.
    return (value + amount).clamp(0.0, 1.0);
  }

  static double _max3(double a, double b, double c) {
    return a > b
        ? (a > c ? a : c)
        : (b > c ? b : c);
  }

  static int _clamp(double value) {
    return value.round().clamp(0, 255);
  }
}
