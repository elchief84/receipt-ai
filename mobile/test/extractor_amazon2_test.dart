import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

const amazonTailOcr =
    'Riepilogo dell\'ordine\n'
    'Subtotale articoli:\n'
    'Costi di spedizione:\n'
    'Totale IVA esclusa:\n'
    'IVA stimata:\n'
    '2\n'
    'Totale:\n'
    'Stampa\n'
    '160,52 €\n'
    '0,00 €\n'
    '160,52 €\n'
    '35,31 €\n'
    '2\n'
    '195,83 €';

void main() {
  test('repro amazon foto2: subtotale tra Totale e gran totale', () {
    expect(
      TransactionExtractor().extract(amazonTailOcr).total,
      195.83,
    );
  });
}
