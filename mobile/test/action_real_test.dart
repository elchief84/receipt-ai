import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

import 'fixtures/action_real.dart';

void main() {
  test('action real geometry: structure + prices from device dump', () {
    final ocr = actionRealTexts.join('\n');
    final draft = TransactionExtractor().extract(ocr);
    expect(draft.total, 52.49);

    final layout = ReceiptLayoutParser.parse(
      actionRealTexts,
      actionRealBoxes,
      draft.total,
    );
    expect(layout.declaredCount, 15);

    final descs = layout.items.map((e) => e.description).toList();
    for (final fragment in [
      'alzata',
      'disney palla di nat',
      'figura led',
      'legno',
      'mini matters',
      'elbow grease',
      'detersivo piatti',
      'colorare',
      'harry potter',
      'mosaico',
      'lavagnetta',
    ]) {
      expect(
        descs.any((d) => d.contains(fragment)),
        isTrue,
        reason: 'missing fragment "$fragment"',
      );
    }
    for (final banned in [
      'Auth',
      'DOCUMENTO',
      'Mastercard',
      'contactless',
      'arrivederci',
      'Nome pref',
    ]) {
      expect(
        descs.any((d) => d.contains(banned)),
        isFalse,
        reason: 'trailer leak "$banned"',
      );
    }

    final priced = layout.items.where((e) => e.price != null).toList();
    // The alzata row carries its price on the same visual row.
    final alzata = layout.items.firstWhere(
      (e) => e.description.contains('alzata'),
    );
    expect(alzata.price, 7.95);
    // Dims line joins its product; felt board is one item @4,99.
    expect(alzata.description, contains('21x20x26cm'));
    final lavagnetta = layout.items.firstWhere(
      (e) => e.description.contains('lavagnetta'),
    );
    expect(lavagnetta.description, contains('30x45cm'));
    expect(lavagnetta.price, 4.99);
    // 15 prices for a 52,49 total that adds up exactly.
    expect(priced.length, 15);
    expect(layout.sumOk, isTrue);
    // IVA-summary figures must never become item prices.
    for (final e in priced) {
      expect(e.price, isNot(anyOf(0.12, 8.93, 9.05, 2.87, 40.57, 43.44)));
    }
    // Full dump for paper verification (see issue thread).
    for (final e in layout.items) {
      // ignore: avoid_print
      print('ITEM [${e.price?.toStringAsFixed(2)}] ${e.description}');
    }
    // ignore: avoid_print
    print('SUMOK: ${layout.sumOk} PRICED: ${priced.length}/${layout.items.length}');
  });
}
