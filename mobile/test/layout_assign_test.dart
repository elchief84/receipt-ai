import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

LineGeometry _g(double l, double t, double r, double b) => LineGeometry(
  Rect.fromLTRB(l, t, r, b),
  corners: [Offset(l, t), Offset(r, t), Offset(r, b), Offset(l, b)],
);

void main() {
  test('unified assigner: an amount claims the item on its band', () {
    // Price rows overlap their product only by 3/10 of the height: below
    // Phase B's 0.3 threshold, so they reach the unified assigner as
    // bare rows and must be matched visually, not by stray order.
    final lines = [
      'CONAD SUPERSTORE',
      'P.IVA 01234567890',
      'ARTICOLI',
      'ALFA MAGLIA ROSSA',
      'BETA SCARPA BLU',
      '1,00',
      '2,00',
      'TOTALE COMPLESSIVO 3,00',
    ];
    final geoms = <LineGeometry?>[
      _g(0, 0, 200, 18),
      _g(0, 25, 200, 43),
      _g(0, 50, 120, 68),
      _g(0, 100, 150, 110),
      _g(0, 140, 150, 150),
      _g(250, 107, 300, 117),
      _g(250, 147, 300, 157),
      _g(0, 190, 260, 208),
    ];
    final layout = ReceiptLayoutParser.parseLines(lines, geoms, 3.00);
    expect(layout.items, hasLength(2));
    expect(layout.items[0].description, 'ALFA MAGLIA ROSSA');
    expect(layout.items[0].price, 1.00);
    expect(layout.items[1].description, 'BETA SCARPA BLU');
    expect(layout.items[1].price, 2.00);
    expect(layout.sumOk, isTrue);
  });
}
