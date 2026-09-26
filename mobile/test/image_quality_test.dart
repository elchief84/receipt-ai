import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/image_quality.dart';

Uint8List _frame(int w, int h, int Function(int x, int y) luma) {
  final bytes = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = luma(x, y);
      final i = (y * w + x) * 4;
      bytes[i] = v;
      bytes[i + 1] = v;
      bytes[i + 2] = v;
      bytes[i + 3] = 255;
    }
  }
  return bytes;
}

void main() {
  test('sharp high-contrast frame passes', () {
    final rgba = _frame(600, 600, (x, y) => ((x ~/ 4 + y ~/ 4) % 2 == 0) ? 0 : 255);
    final r = ImageQuality.assessRgba(rgba, 600, 600);
    expect(r.ok, isTrue);
    expect(r.focus, greaterThan(minFocusScore));
  });

  test('uniform frame is rejected as blurry', () {
    final rgba = _frame(600, 600, (_, _) => 128);
    final r = ImageQuality.assessRgba(rgba, 600, 600);
    expect(r.ok, isFalse);
    expect(r.reason, contains('sfocata'));
  });

  test('tiny frame is rejected on resolution', () {
    final rgba = _frame(200, 200, (x, y) => ((x + y) % 2) * 255);
    final r = ImageQuality.assessRgba(rgba, 200, 200);
    expect(r.ok, isFalse);
    expect(r.reason, contains('Risoluzione'));
  });
}
