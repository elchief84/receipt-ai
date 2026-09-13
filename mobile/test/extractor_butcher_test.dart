import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

const butcherOcr =
    'MACELLERIA t\n'
    'LA IMPERIALE SNC\n'
    'DI GALLI F. &M.\n'
    'VIA MARSALA, 97\n'
    'MANCIANO (GR)\n'
    'TELEFONO: 0564.620438\n'
    'P.IVA O0808160535\n'
    'REPARTO_1\n'
    'TOTALE EURO\n'
    'CONTANTE\n'
    'GRAZIE\n'
    'ARRIVEDERCI\n'
    'EURO\n'
    '50,00\n'
    'E\n'
    '50,00\n'
    'CASSA:\n'
    '03-05-2018\n'
    'N.SCONTR.FISCALE\n'
    'A 04 80518294\n'
    '50.00\n'
    '01\n'
    '21:28\n'
    '17';

void main() {
  test('repro macelleria: TOTALE senza cifra vicina', () {
    final draft = TransactionExtractor().extract(butcherOcr);
    expect(draft.total, 50.00);
    expect(draft.date, '03/05/2018');
  });

  test('TOTALE nudo con cifra 3 righe sotto', () {
    const ocr = 'SHOP\n01/09/2026\n\nTOTALE EURO\nCONTANTE\nGRAZIE\n12,30';
    expect(TransactionExtractor().extract(ocr).total, 12.30);
  });

  test('keyword senza cifra + RESTO in coda: non prende il resto', () {
    const ocr = 'SHOP\n01/09/2026\n\nTOTALE EURO\nCONTANTE 20,00\nRESTO 7,70';
    expect(TransactionExtractor().extract(ocr).total, 20.00);
  });
}
