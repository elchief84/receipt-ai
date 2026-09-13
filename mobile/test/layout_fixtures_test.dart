import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

import 'fixtures/receipts.dart';

List<String> _lines(String ocr) =>
    ocr.split('\n').map((l) => l.trim()).toList();

void main() {
  for (final fixture in allFixtures) {
    test('${fixture.name}: total + items + trailer exclusion', () {
      final draft = TransactionExtractor().extract(fixture.ocr);
      expect(draft.total, fixture.expectedTotal);

      final layout = ReceiptLayoutParser.parse(
        _lines(fixture.ocr),
        null,
        draft.total,
      );
      final descs = layout.items.map((e) => e.description).toList();
      for (final expected in fixture.expectedItems) {
        expect(
          descs.any((d) => d.contains(expected.$1)),
          isTrue,
          reason: 'missing item containing "${expected.$1}"',
        );
        if (expected.$2 != null) {
          final match = layout.items.firstWhere(
            (e) => e.description.contains(expected.$1),
          );
          expect(match.price, expected.$2);
        }
      }
      for (final fragment in fixture.expectedContains) {
        expect(
          descs.any((d) => d.contains(fragment)),
          isTrue,
          reason: 'missing fragment "$fragment"',
        );
      }
      for (final banned in fixture.expectedAbsent) {
        expect(
          descs.any((d) => d.contains(banned)),
          isFalse,
          reason: 'trailer leak "$banned"',
        );
      }
      if (fixture.expectSumOk) {
        expect(layout.sumOk, isTrue);
      }
    });
  }

  test('conad sample: priced items sum to total', () {
    const ocr = 'CONAD SUPERSTORE\n12/09/2026\n\nLATTE INTERO 1L 1.49\n'
        'PASTA BARILLA 500G 1.29\n\nTOTALE 2.78';
    final layout = ReceiptLayoutParser.parse(_lines(ocr), null, 2.78);
    expect(layout.items, hasLength(2));
    expect(layout.items[0].price, 1.49);
    expect(layout.sumOk, isTrue);
  });

  test('sum mismatch is reported, not hidden', () {
    const ocr = 'SHOP\nLATTE 1.49\nPANE 9.99\nTOTALE 2.78';
    final layout = ReceiptLayoutParser.parse(_lines(ocr), null, 2.78);
    expect(layout.sumOk, isFalse);
  });

  test('sconto attaches to the item above and corrects it', () {
    const ocr = 'SHOP\nPANE 5,00\nSCONTO TESSERA 1,00\nTOTALE 4,00';
    final layout = ReceiptLayoutParser.parse(_lines(ocr), null, 4.00);
    expect(layout.items, hasLength(1));
    expect(layout.items.first.price, 4.00);
    expect(layout.sumOk, isTrue);
  });

  test('declared count is extracted when printed', () {
    const ocr = 'SHOP\nPANE 2,00\nNUMERO DI ARTICOLI: 15\nTOTALE 2,00';
    final layout = ReceiptLayoutParser.parse(_lines(ocr), null, 2.00);
    expect(layout.declaredCount, 15);
  });
}
