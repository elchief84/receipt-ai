import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

const amazonOcr =
    'Riepilogo dell\'ordine\n'
    'Ordine effettuato il: 9 agosto 2026 Ordine n. 405-5553713-2912319\n'
    'Venduto da: Amazon.it\n'
    'XIAOMI POco C85, Smartphone 6+128GB, Viola, 6000mAh\n'
    '129,90€\n'
    'Venduto da: Nayana-EU\n'
    'FDHYFGDY Cover per Xiaomi Redmi 15C\n'
    '7,69€\n'
    'Fisher-Price Tavolino attività 4-in-1 e cavalletto, multilingue\n'
    '58,24€\n'
    'Subtotale articoli:\n'
    'Totale:\n'
    'Condizioni generali di uso e vendita\n'
    '1996-2026 Amazon.com, Inc. o società affiliate\n'
    'Stampa\n'
    '160,52 €\n'
    '0,00€\n'
    '160,52 €\n'
    '35,31 €\n'
    '195,83 €';

void main() {
  test('repro amazon: totale addebitato, non subtotale', () {
    final draft = TransactionExtractor().extract(amazonOcr);
    expect(draft.total, 195.83);
  });

  test('data con mese in lettere', () {
    expect(
      TransactionExtractor().extract('Ordine effettuato il: 9 agosto 2026')
          .date,
      '09/08/2026',
    );
  });
}
