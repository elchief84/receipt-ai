import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

/// Two-column RT layout (Action): descriptions left, prices right.
/// Without boxes the prices stay orphaned; with boxes they pair by row.
List<String> get lines => [
      'ARTICOLI',
      'disney palla di nat',
      'detersivo piatti a good',
      'harry potter quilling',
      'TOTALE',
      '7,95',
      '3,99',
      '2,99',
      '52,49',
    ];

List<Rect?> boxesLikeMlKit() => [
      const Rect.fromLTWH(0, 0, 100, 10), // ARTICOLI
      const Rect.fromLTWH(0, 10, 60, 10), // desc 1
      const Rect.fromLTWH(0, 20, 60, 10), // desc 2
      const Rect.fromLTWH(0, 30, 60, 10), // desc 3
      const Rect.fromLTWH(0, 40, 60, 10), // TOTALE
      const Rect.fromLTWH(70, 10, 30, 10), // 7,95 same row as desc 1
      const Rect.fromLTWH(70, 20, 30, 10), // 3,99 same row as desc 2
      const Rect.fromLTWH(70, 30, 30, 10), // 2,99 same row as desc 3
      const Rect.fromLTWH(70, 60, 30, 10), // 52,49 grand total, no row
    ];

void main() {
  test('without boxes each description stays separate', () {
    final items = TransactionExtractor.segmentItems(lines);
    expect(items.map((e) => e.description).toList(), hasLength(3));
    expect(items.every((e) => e.price == null), isTrue);
  });

  test('with boxes prices pair by visual row, totals excluded', () {
    final items = TransactionExtractor.segmentItems(lines, boxesLikeMlKit());
    expect(items.map((e) => e.description).toList(), hasLength(3));
    expect(items[0].price, 7.95);
    expect(items[1].price, 3.99);
    expect(items[2].price, 2.99);
  });

  test('desc lines sharing one price row join into a single item', () {
    const ls = [
      'ARTICOLI',
      'disney palla di nat',
      'plast ica',
      'ventosa singola prodotto lungo descrittivo',
      'TOTALE',
      '7,95',
    ];
    final boxes = [
      const Rect.fromLTWH(0, 0, 100, 10),
      const Rect.fromLTWH(0, 10, 60, 10),
      const Rect.fromLTWH(0, 20, 60, 10),
      const Rect.fromLTWH(0, 30, 70, 10),
      const Rect.fromLTWH(0, 50, 60, 10),
      const Rect.fromLTWH(70, 15, 30, 10),
    ];
    final items = TransactionExtractor.segmentItems(ls, boxes);
    expect(items.map((e) => e.description).toList(), hasLength(2));
    expect(items[0].description, 'disney palla di nat plast ica');
    expect(items[0].price, 7.95);
    expect(items[1].price, isNull);
  });

  test('short fragment hugs the priced item above', () {
    const ls = ['ARTICOLI', 'disney figura led con', 'ventosa', 'TOTALE', '58,24'];
    final boxes = [
      const Rect.fromLTWH(0, 0, 100, 10),
      const Rect.fromLTWH(0, 10, 60, 10), // disney row
      const Rect.fromLTWH(0, 21, 60, 9), // ventosa, gap 1 < 1.5*10
      const Rect.fromLTWH(0, 50, 60, 10), // TOTALE
      const Rect.fromLTWH(70, 10, 30, 10), // 58,24 overlaps disney only
    ];
    final items = TransactionExtractor.segmentItems(ls, boxes);
    expect(items, hasLength(1));
    expect(items.first.description, 'disney figura led con ventosa');
    expect(items.first.price, 58.24);
  });

  test('tilted photo still pairs rows in physical order', () {
    // 8px drift across a 55px column gap (~8° tilt): overlap-only
    // clustering breaks here; the de-skew estimate must recover it.
    const ls = [
      'ARTICOLI',
      'disney palla di nat',
      'detersivo piatti',
      'harry potter quilling',
      'TOTALE',
      '7,95',
      '3,99',
      '2,99',
    ];
    final boxes = <Rect?>[
      const Rect.fromLTWH(0, 0, 100, 10), // ARTICOLI
      const Rect.fromLTWH(0, 10, 60, 10),
      const Rect.fromLTWH(0, 30, 60, 10),
      const Rect.fromLTWH(0, 50, 60, 10),
      const Rect.fromLTWH(0, 90, 60, 10), // TOTALE
      const Rect.fromLTWH(70, 18, 30, 10), // 7,95 drifted +8
      const Rect.fromLTWH(70, 38, 30, 10), // 3,99 drifted +8
      const Rect.fromLTWH(70, 58, 30, 10), // 2,99 drifted +8
    ];
    final items = TransactionExtractor.segmentItems(ls, boxes);
    expect(items.map((e) => e.description).toList(), hasLength(3));
    expect(items[0].price, 7.95);
    expect(items[1].price, 3.99);
    expect(items[2].price, 2.99);
  });
}
