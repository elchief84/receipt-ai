import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

void main() {
  test('repro utente: coda di soli importi senza keyword', () {
    const ocr =
        'FARMACIA COMUNALE\n10/09/2026\n\nMOMENT 200MG 12CPR        8,60\nCEROTTI                    5,00\n\n13,60\n0,00\n13,60\n13,60';
    expect(TransactionExtractor().extract(ocr).total, 13.60);
  });

  test('fallback non prende mai il RESTO', () {
    const ocr = 'SHOP\n01/09/2026\n\nPANE 13,60\n\nCONTANTI 20,00\nRESTO 6,40';
    expect(TransactionExtractor().extract(ocr).total, 20.00);
  });

  test('keyword con errori OCR (TOTAIE)', () {
    const ocr = 'FARMACIA\n10/09/2026\n\nMOMENT 8,60\n\nTOTAIE COMPLESSIVO 13,60';
    expect(TransactionExtractor().extract(ocr).total, 13.60);
  });
}
