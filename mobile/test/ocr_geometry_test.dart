import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/ocr.dart';

void main() {
  test('OcrLine carries confidence, angle and corners', () {
    final line = OcrLine(
      'LATTE 1.49',
      const Rect.fromLTWH(0, 10, 100, 12),
      confidence: 0.82,
      angle: 1.5,
      corners: const [Offset(0, 10), Offset(100, 11), Offset(100, 22)],
    );
    expect(line.confidence, 0.82);
    expect(line.angle, 1.5);
    expect(line.corners, hasLength(3));
    expect(line.corners.first.dx, 0);
  });

  test('FakeOcrEngine exposes per-line angles and confidences', () async {
    final engine = FakeOcrEngine(
      'A\nB',
      geometry: const [Rect.fromLTWH(0, 0, 10, 2), Rect.fromLTWH(0, 5, 10, 2)],
      angles: const [2.0, null],
      confidences: const [0.9, 0.3],
    );
    final result = await engine.recognize('ignored');
    expect(result.lines, hasLength(2));
    expect(result.lines[0].angle, 2.0);
    expect(result.lines[0].confidence, 0.9);
    expect(result.lines[1].angle, isNull);
    expect(result.lines[1].confidence, 0.3);
    expect(result.lines[0].text, 'A');
  });

  test('FakeOcrEngine defaults to null geometry metadata', () async {
    final result = await FakeOcrEngine('solo').recognize('ignored');
    expect(result.lines.single.confidence, isNull);
    expect(result.lines.single.angle, isNull);
    expect(result.lines.single.corners, isEmpty);
  });
}
