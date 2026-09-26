import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

/// Physical line: axis box + corners encoding a global tilt [slope].
/// Axis `top` follows the tilt so the bounding box matches the quad.
LineGeometry _tilted(
  double l,
  double y0,
  double r,
  double h,
  double slope,
) {
  final top = y0 + slope * l;
  final bottom = y0 + slope * r + h;
  return LineGeometry(
    Rect.fromLTRB(l, top, r, bottom),
    corners: [
      Offset(l, y0 + slope * l),
      Offset(r, y0 + slope * r),
      Offset(r, y0 + slope * r + h),
      Offset(l, y0 + slope * l + h),
    ],
  );
}

void main() {
  test('deskew from corners pairs prices to the right row despite tilt', () {
    const slope = 0.1;
    // Rows are emitted scrambled, as ML Kit does.
    final lines = [
      'CONAD SUPERSTORE',
      'P.IVA 01234567890',
      'ARTICOLI',
      'PASTA BARILLA', // row 2 desc
      '1,49', // row 1 price
      'LATTE INTERO', // row 1 desc
      '2,51', // row 2 price
      'TOTALE COMPLESSIVO 4,00',
    ];
    final geoms = <LineGeometry?>[
      _tilted(0, 0, 200, 20, slope), // CONAD
      _tilted(0, 50, 200, 18, slope), // P.IVA
      _tilted(0, 100, 120, 18, slope), // ARTICOLI
      _tilted(0, 200, 150, 20, slope), // row 2 desc
      _tilted(250, 150, 300, 20, slope), // row 1 price
      _tilted(0, 150, 150, 20, slope), // row 1 desc
      _tilted(250, 200, 300, 20, slope), // row 2 price
      _tilted(0, 250, 260, 20, slope), // TOTALE
    ];
    final layout = ReceiptLayoutParser.parseLines(lines, geoms, 4.00);
    final byPrice = {
      for (final e in layout.items) e.description: e.price,
    };
    expect(byPrice['LATTE INTERO'], 1.49);
    expect(byPrice['PASTA BARILLA'], 2.51);
    expect(layout.sumOk, isTrue);
  });

  test('same-line price groups with its description without tilt', () {
    final lines = [
      'CONAD SUPERSTORE',
      'P.IVA 01234567890',
      'ARTICOLI',
      'LATTE INTERO',
      '1,49',
      'TOTALE COMPLESSIVO 4,00',
    ];
    final geoms = <LineGeometry?>[
      LineGeometry(const Rect.fromLTWH(0, 0, 200, 20)),
      LineGeometry(const Rect.fromLTWH(0, 25, 200, 18)),
      LineGeometry(const Rect.fromLTWH(0, 50, 120, 18)),
      LineGeometry(const Rect.fromLTWH(0, 80, 150, 20)),
      LineGeometry(const Rect.fromLTWH(250, 81, 300, 19)),
      LineGeometry(const Rect.fromLTWH(0, 120, 260, 20)),
    ];
    final layout = ReceiptLayoutParser.parseLines(lines, geoms, 4.00);
    expect(layout.items.single.description, 'LATTE INTERO');
    expect(layout.items.single.price, 1.49);
  });
}
