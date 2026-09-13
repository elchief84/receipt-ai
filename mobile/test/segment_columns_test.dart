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
  test('without boxes prices stay orphaned', () {
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
}
