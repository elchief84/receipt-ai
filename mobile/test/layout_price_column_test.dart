import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

LayoutRow _row(String text, double l, double t, double r, double b) =>
    LayoutRow([0], text, Rect.fromLTRB(l, t, r, b));

void main() {
  test('detects a right-aligned price column', () {
    final rows = [
      _row('7,95', 70, 10, 100, 20),
      _row('3,99', 70, 20, 100, 30),
      _row('2,99', 71, 30, 101, 40),
    ];
    final col = ReceiptLayoutParser.detectPriceColumn(rows, [0, 1, 2]);
    expect(col, isNotNull);
    expect(col!.right, closeTo(100, 1.5));
    expect(col.count, 3);
  });

  test('no column when right edges are scattered', () {
    final rows = [
      _row('7,95', 0, 10, 40, 20),
      _row('3,99', 60, 20, 70, 30),
      _row('2,99', 0, 30, 100, 40),
    ];
    expect(ReceiptLayoutParser.detectPriceColumn(rows, [0, 1, 2]), isNull);
  });

  test('needs at least three samples', () {
    final rows = [_row('7,95', 70, 10, 100, 20), _row('3,99', 70, 20, 100, 30)];
    expect(ReceiptLayoutParser.detectPriceColumn(rows, [0, 1]), isNull);
  });

  test('right edge prefers rotated corners over the padded box', () {
    final rows = [
      LayoutRow([0], '7,95', const Rect.fromLTRB(70, 10, 100, 20), corners: const [
        Offset(70, 10),
        Offset(98, 12),
        Offset(98, 20),
        Offset(70, 18),
      ]),
      LayoutRow([1], '3,99', const Rect.fromLTRB(70, 20, 100, 30), corners: const [
        Offset(70, 20),
        Offset(98, 22),
        Offset(98, 30),
        Offset(70, 28),
      ]),
      LayoutRow([2], '2,99', const Rect.fromLTRB(70, 30, 100, 40), corners: const [
        Offset(70, 30),
        Offset(99, 32),
        Offset(99, 40),
        Offset(70, 38),
      ]),
    ];
    final col = ReceiptLayoutParser.detectPriceColumn(rows, [0, 1, 2]);
    expect(col, isNotNull);
    expect(col!.right, closeTo(98.5, 1.0));
  });
}
