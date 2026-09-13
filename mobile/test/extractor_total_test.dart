import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

void main() {
  test('repro utente: TOTALE COMPLESSIVO con largo spazio', () {
    const ocr =
        'FARMACIA COMUNALE\n10/09/2026\n\nMOMENT 200MG 12CPR        8,60\nCEROTTI                    5,00\n\nTOTALE COMPLESSIVO                            13,60';
    expect(TransactionExtractor().extract(ocr).total, 13.60);
  });

  test('due punti dopo TOTALE', () {
    const ocr = 'BAR CENTRALE\n01/09/2026\n\nCAFFE 1,00\n\nTOTALE: 13,00';
    expect(TransactionExtractor().extract(ocr).total, 13.00);
  });

  test('SUBTOTALE non deve vincere sul TOTALE', () {
    const ocr =
        'SHOP\n01/09/2026\n\nSUBTOTALE 10,00\nSCONTO 2,00\n\nTOTALE 8,00';
    expect(TransactionExtractor().extract(ocr).total, 8.00);
  });

  test('TOTALE e importo su due righe', () {
    const ocr = 'SHOP\n01/09/2026\n\nPANE 2,00\n\nTOTALE\n13,60';
    expect(TransactionExtractor().extract(ocr).total, 13.60);
  });
}
