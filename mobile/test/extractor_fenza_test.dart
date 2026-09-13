import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

const fenzaOcr =
    'FARMACIA FENZA S. A. S.\n'
    'DELLA DOTT. SSA FENZA ANNA & C.\n'
    'VIA FUORNI N.3 SALERNO\n'
    'PARTITA IVA 06221240655\n'
    'TELEFONO 089/301152\n'
    'DOCUMENTO COMMERCIALE\n'
    'di vendi ta o pres tazi one\n'
    'Descrizi one\n'
    'D. M. CE ALOVEX P\n'
    'Dir 93/42/CEE e\n'
    'TTALE CONPLESSIVO\n'
    'DI CUI IVA\n'
    'Pagamento elettroni co\n'
    'Impor to pagato\n'
    '1211194 REG. 001 OP. 1\n'
    'IVA\n'
    'VI\n'
    '31-08-2026 18:14\n'
    'DOCUMENTO N. 2333-0105\n'
    '* Inp. De traibile 13.60\n'
    'Prezzo( €)\n'
    '13,60\n'
    'C.F. / P.IVA DEL CLIENTE\n'
    'RMNMHL25D13H703G\n'
    'RT 45MQUO06864\n'
    '13,60\n'
    '0,00\n'
    '13,60';

void main() {
  test('repro fenza: totale e data ok, un unico item dal corpo', () {
    final draft = TransactionExtractor().extract(fenzaOcr);
    expect(draft.total, 13.60);
    expect(draft.date, '31/08/2026');
    final items = TransactionExtractor.segmentItems(
      fenzaOcr.split('\n').map((l) => l.trim()).toList(),
    );
    // Prices print only in the totals block: the RT body block still
    // names the purchase. Zero garbage items, one joined description
    // with no price.
    expect(items, hasLength(1));
    expect(items.first.description, contains('ALOVEX'));
    expect(items.first.price, isNull);
  });
}
