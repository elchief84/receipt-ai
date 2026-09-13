import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

void main() {
  test('extracts merchant, date and Italian total', () {
    const ocr =
        'CONAD SUPERSTORE\n12/09/2026\n\nLATTE INTERO 1L          1.49\n\nTOTALE                 10.60';
    final draft = TransactionExtractor().extract(ocr);
    expect(draft.merchantRaw, 'CONAD SUPERSTORE');
    expect(draft.date, '12/09/2026');
    expect(draft.total, 10.60);
    expect(draft.currency, 'EUR');
  });

  test('parses thousands separator 1.234,56', () {
    const ocr = 'MEDIAWORLD\n01/01/2026\n\nTV LED              1.234,56\n\nTOTALE 1.234,56';
    expect(TransactionExtractor().extract(ocr).total, 1234.56);
  });

  test('empty text gives empty draft', () {
    final draft = TransactionExtractor().extract('');
    expect(draft.merchantRaw, '');
    expect(draft.total, 0.0);
  });
}
