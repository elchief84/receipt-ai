import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

/// Action store receipt: 15 products named WITHOUT prices, prices only
/// in the tail block. Body-first segmentation must list descriptions
/// and ignore codes, trailer junk and repeated totals.
const actionOcr =
    'IACTIDN\n'
    'D182 Ponteca gnano Faiano\n'
    'P.I IT10955660963\n'
    '13-09-2026 15:20:0/\n'
    'ARTICOLI\n'
    '3207757\n'
    '3223372 alzata dec. 2rip\n'
    '21x20x26cm div, co\n'
    'disney palla di nat\n'
    'plast ica\n'
    '3207757 disney palla di nat. 4pz\n'
    'plastica\n'
    '3225221\n'
    '3224795\n'
    '3213203\n'
    '2562632\n'
    'DOCUMENTO COMMERCIALE\n'
    'di vendita o prestazione\n'
    'disney figura led con\n'
    'ventosa\n'
    'legno 23pz\n'
    'detersivo piatti a good\n'
    'clean 500 ml\n'
    '1ibro da colorare\n'
    'lavagnetta in feltro\n'
    '30x45cm\n'
    'TOTALE\n'
    'METODO/I DI PAGAMENTO\n'
    'Carta\n'
    'NUMERO DI ARTICOLI: 15\n'
    'SPECIFICA IVA\n'
    'IVA\n'
    '0,12\n'
    '8,93\n'
    '9,05\n'
    'Auth. code\n'
    '0,89\n'
    '4,99\n'
    '52,49\n'
    '13/09/2026\n'
    '15:20:01\n'
    '49,50\n'
    '52,49\n'
    '*****5135\n'
    '€ 52,49';

void main() {
  test('action: descriptions listed, codes and trailer junk out', () {
    final items = TransactionExtractor.segmentItems(
      actionOcr.split('\n').map((l) => l.trim()).toList(),
    );
    final descs = items.map((e) => e.description).toList();
    expect(descs.any((d) => d.contains('alzata')), isTrue);
    expect(descs.any((d) => d.contains('disney palla di nat')), isTrue);
    expect(descs.any((d) => d.contains('disney figura')), isTrue);
    expect(descs.any((d) => d.contains('detersivo piatti')), isTrue);
    expect(descs.any((d) => d.contains('1ibro da colorare')), isTrue);
    expect(descs.any((d) => d.contains('lavagnetta')), isTrue);
    expect(descs.any((d) => d.contains('Auth')), isFalse);
    expect(descs.any((d) => d.contains('DOCUMENTO')), isFalse);
    expect(descs.any((d) => RegExp(r'^\d+$').hasMatch(d)), isFalse);
    // No prices on description lines in this layout.
    expect(items.every((e) => e.price == null), isTrue);
  });
}
