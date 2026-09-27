import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

/// Real failing case (Farmacia Fenza): the header row merges the left
/// "Descrizione" title with the right-column labels "IVA" and "Prezzo".
/// The merged text contains a trailer token ("IVA") and exceeds the
/// short-marker limit — it must still be recognised as the body start,
/// or the whole product body is skipped.
void main() {
  test('header merged with right-column labels still starts the body', () {
    final lines = [
      'FARMACIA FENZA S. A. S.',
      'PARTITA IVA 06221240655',
      'DOCUMENTO COMMERCIALE',
      'Descrizi one',
      'IVA',
      'Prezzo( €)',
      'D. M. CE ALOVEX P',
      'VI',
      '13,60',
      'Dir 93/42/CEE e',
      'TTALE CONPLESSIVO',
      '13,60',
    ];
    final geoms = <LineGeometry?>[
      LineGeometry(const Rect.fromLTRB(0, 0, 800, 40)),
      LineGeometry(const Rect.fromLTRB(0, 50, 800, 90)),
      LineGeometry(const Rect.fromLTRB(0, 100, 800, 140)),
      LineGeometry(const Rect.fromLTRB(0, 150, 400, 190)), // Descrizi one
      LineGeometry(const Rect.fromLTRB(800, 150, 900, 190)), // IVA
      LineGeometry(const Rect.fromLTRB(910, 150, 1100, 190)), // Prezzo( €)
      LineGeometry(const Rect.fromLTRB(0, 200, 400, 240)), // D. M. CE ALOVEX P
      LineGeometry(const Rect.fromLTRB(800, 200, 900, 240)), // VI
      LineGeometry(const Rect.fromLTRB(910, 200, 1100, 240)), // 13,60
      LineGeometry(const Rect.fromLTRB(0, 250, 400, 290)), // Dir 93/42/CEE
      LineGeometry(const Rect.fromLTRB(0, 300, 700, 340)), // TTALE CONPLESSIVO
      LineGeometry(const Rect.fromLTRB(800, 300, 1000, 340)), // 13,60
    ];
    final rows = ReceiptLayoutParser.typedRows(lines, geoms);
    expect(rows.firstWhere((r) => r.row.text.contains('Descrizi')).kind,
        RowKind.bodyStart);

    final layout = ReceiptLayoutParser.parseLines(lines, geoms, 13.60);
    final priced = layout.items.where((e) => e.price != null).toList();
    expect(priced, hasLength(1));
    expect(priced.single.price, 13.60);
    expect(priced.single.description, contains('ALOVEX'));
    expect(layout.sumOk, isTrue);
  });
}
