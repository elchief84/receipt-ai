import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

/// Real failing case (Autogrill): an IVA column ("10,00%") sits between
/// the description and the price and merges into the same visual row. The
/// percentage must never be taken as the price (it is left-most) nor
/// pollute the description.
void main() {
  test('IVA percentage cell is stripped, price is the real one', () {
    final lines = [
      'AUTOGRILL',
      'P.IVA 01234567890',
      'DESCRIZIONE',
      'Focaccia',
      '10,00%',
      '6,00',
      'Servizio',
      '0,90',
      'TOTALE COMPLESSIVO 6,90',
    ];
    final geoms = <LineGeometry?>[
      LineGeometry(const Rect.fromLTRB(0, 0, 300, 30)),
      LineGeometry(const Rect.fromLTRB(0, 40, 300, 70)),
      LineGeometry(const Rect.fromLTRB(0, 80, 300, 110)),
      LineGeometry(const Rect.fromLTRB(0, 120, 300, 150)), // Focaccia
      LineGeometry(const Rect.fromLTRB(500, 120, 600, 150)), // 10,00%
      LineGeometry(const Rect.fromLTRB(700, 120, 800, 150)), // 6,00
      LineGeometry(const Rect.fromLTRB(0, 160, 300, 190)), // Servizio
      LineGeometry(const Rect.fromLTRB(700, 160, 800, 190)), // 0,90
      LineGeometry(const Rect.fromLTRB(0, 200, 400, 230)),
    ];
    final rows = ReceiptLayoutParser.typedRows(lines, geoms);
    expect(
      rows.firstWhere((r) => r.row.text.contains('Focaccia')).kind,
      RowKind.priced,
    );

    final layout = ReceiptLayoutParser.parseLines(lines, geoms, 6.90);
    final focaccia = layout.items.firstWhere(
      (e) => e.description.toLowerCase().contains('focaccia'),
    );
    expect(focaccia.price, 6.00);
    expect(focaccia.description, isNot(contains('%')));
    expect(layout.sumOk, isTrue);
  });
}
