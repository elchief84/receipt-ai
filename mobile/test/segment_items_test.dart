import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

const amazonItemsOcr =
    'Riepilogo dell\'ordine\n'
    'Venduto da: Amazon.it\n'
    'XIAOMI POCO C85, Smartphone 6+128GB, Viola, 6000mAh\n'
    'Consegnato 11 agosto\n'
    'Il periodo utile per il reso è scaduto il 25 agosto 2026\n'
    '129,90€\n'
    'FDHYFGDY Cover per Xiaomi Redmi 15C\n'
    'TPU Custodia Protettiva-Trasparente\n'
    'Venduto da: Nayana-EU\n'
    '7,69€\n'
    'Fisher-Price Tavolino attività 4-in-1 e cavalletto, multilingue\n'
    '58,24€\n'
    'Torna su\n'
    'Subtotale articoli:\n'
    'Totale:\n'
    'Stampa\n'
    '160,52 €\n'
    '195,83 €';

void main() {
  test('amazon: exactly the 3 products, no contorno', () {
    final items = TransactionExtractor.segmentItems(
      amazonItemsOcr.split('\n').map((l) => l.trim()).toList(),
    );
    expect(items, hasLength(3));
    expect(items[0], contains('XIAOMI'));
    expect(items[1], contains('Custodia'));
    expect(items[2], contains('Fisher-Price'));
  });

  test('fiscal receipt: inline descriptions', () {
    const ocr =
        'CONAD SUPERSTORE\n12/09/2026\n\nLATTE INTERO 1L 1.49\nDETERSIVO 5.99\n\nTOTALE 10.60';
    final items = TransactionExtractor.segmentItems(
      ocr.split('\n').map((l) => l.trim()).toList(),
    );
    expect(items, hasLength(2));
  });

  test('bare repeated totals are skipped', () {
    const ocr =
        'FARMACIA\n10/09/2026\n\nMOMENT 8,60\n\nTOTALE COMPLESSIVO 13,60\n13,60\n13,60';
    final items = TransactionExtractor.segmentItems(
      ocr.split('\n').map((l) => l.trim()).toList(),
    );
    expect(items, ['MOMENT']);
  });

  test('payment and meta lines never become items', () {
    const ocr =
        'SHOP\n01/09/2026\n\nPANE 13,60\n\nCONTANTI 20,00\nRESTO 6,40';
    final items = TransactionExtractor.segmentItems(
      ocr.split('\n').map((l) => l.trim()).toList(),
    );
    expect(items, ['PANE']);
  });
}
