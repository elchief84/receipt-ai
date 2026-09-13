import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/document_gate.dart';

const butcherOcr =
    'MACELLERIA t\nLA IMPERIALE SNC\nP.IVA O0808160535\nREPARTO_1\n'
    'TOTALE EURO\nCONTANTE\nGRAZIE ARRIVEDERCI\nEURO\n50,00\n'
    'CASSA:\n03-05-2018\nN.SCONTR.FISCALE\nA 04 80518294\n50.00';

const amazonOcr =
    'Riepilogo dell\'ordine\nVenduto da: Amazon.it\nXIAOMI Smartphone\n'
    '129,90€\nMetodo di pagamento\nSubtotale articoli:\nTotale:\n'
    'IVA stimata:\n160,52 €\n195,83 €';

void main() {
  test('butcher RT receipt accepted (strong markers)', () {
    expect(isFiscalReceipt(butcherOcr), isTrue);
  });

  test('modern RT with DOCUMENTO COMMERCIALE accepted', () {
    expect(
      isFiscalReceipt(
        'FARMACIA\nDOCUMENTO COMMERCIALE di vendita\nTOTALE COMPLESSIVO 13,60\nRT 12345678',
      ),
      isTrue,
    );
  });

  test('amazon order summary rejected despite totale/iva/reso words', () {
    expect(isFiscalReceipt(amazonOcr), isFalse);
  });

  test('empty and garbage rejected', () {
    expect(isFiscalReceipt(''), isFalse);
    expect(isFiscalReceipt('Ciao mondo'), isFalse);
  });
}
