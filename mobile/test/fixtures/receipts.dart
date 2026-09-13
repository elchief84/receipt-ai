/// Real-OCR fixture corpus (ADR: coverage is measured, not felt).
/// Each fixture: raw OCR lines + hand-annotated expected items.
/// New broken receipts land here first, then get fixed permanently.
library;

class ReceiptFixture {
  const ReceiptFixture({
    required this.name,
    required this.ocr,
    required this.expectedTotal,
    this.expectedItems = const [],
    this.expectedContains = const [],
    this.expectedAbsent = const [],
    this.expectSumOk = true,
  });

  final String name;
  final String ocr;
  final double expectedTotal;

  /// Expected (description, price?) pairs in receipt order.
  /// Null price = totals-only layout (price unknown by construction).
  final List<(String, double?)> expectedItems;

  /// Product fragments that must appear across item descriptions.
  final List<String> expectedContains;

  /// Words that must NEVER appear in items (trailer/codes).
  final List<String> expectedAbsent;
  final bool expectSumOk;
}

const fenzaFixture = ReceiptFixture(
  name: 'fenza',
  ocr: 'FARMACIA FENZA S. A. S.\n'
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
      '13,60',
  expectedTotal: 13.60,
  expectedItems: [
    ('D. M. CE ALOVEX P Dir 93/42/CEE e', null),
  ],
  // Single priceless item inherits the total in pipeline (tested there);
  // the parser itself cannot verify a sum without prices.
  expectSumOk: false,
);

const butcherFixture = ReceiptFixture(
  name: 'butcher',
  ocr: 'MACELLERIA t\n'
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
      '17',
  expectedTotal: 50.00,
  // No product rows on this old-format receipt: single purchase = total.
  expectedItems: [],
  expectSumOk: false,
);

const actionFixture = ReceiptFixture(
  name: 'action',
  ocr: 'IACTIDN\n'
      'D182 Ponteca gnano Faiano\n'
      'Via Giacomo Budetti snc\n'
      'P.I IT10955660963\n'
      '13-09-2026 15:20:0/\n'
      'Di82010170247933\n'
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
      '3220980\n'
      'DOCUMENTO COMMERCIALE\n'
      'di vendita o prestazione\n'
      '3210795\n'
      '3207984\n'
      '3220638\n'
      'disney figura led con\n'
      'ventosa\n'
      'Nome pref\n'
      'legno 23pz\n'
      'mini matters set ferrov.\n'
      'elbow grease det\n'
      'aria 00m]\n'
      'clean 500 ml\n'
      'detersivo piatti a good\n'
      'clean 500 ml\n'
      'myo div.\n'
      '1ibro da colorare\n'
      'aquarel 30f. 260gsm\n'
      '1ab31 conf. 3 protez\n'
      'Scherino i phon\n'
      '3211263 harry potter quilling\n'
      'pen div. v,\n'
      'D1820101-10248634\n'
      'detersivo piatti a good\n'
      ') mosaico scaffale\n'
      'bambů\n'
      'lavagnetta in feltro\n'
      '30x45cm\n'
      'TOTALE\n'
      'METODO/I DI PAGAMENTO\n'
      'Carta\n'
      'NUMERO DI ARTICOLI: 15\n'
      'SPECIFICA IVA\n'
      'SALDO RESIDU0\n'
      'Documento N.\n'
      'Server RT\n'
      'CCDC\n'
      'App Action\n'
      '*********6379\n'
      'Modalità inmiSsione\n'
      'Tipo di carta\n'
      'Auth. code\n'
      'IVA\n'
      '0,12\n'
      '8,93\n'
      '9,05\n'
      '70\n'
      '4pz\n'
      'Esc1\n'
      '2,87\n'
      '40,57\n'
      '43,44\n'
      'D18201012625615191449 1573\n'
      '0427-0215\n'
      'BEan903EA\n'
      'Action Italy S.RL\n'
      '7F23178F4F 79EC3D\n'
      'EO1396AB64498C48\n'
      'C8CD43D676A5OC91\n'
      'Grazie e arrivederci!\n'
      '20057 ASSAGO\n'
      'IT109556609o3\n'
      'EUR\n'
      '7,95\n'
      '3,99\n'
      '3,99\n'
      '3,99\n'
      '1,99\n'
      'Caub 1aro entro 8 giorni Con SCunt no\n'
      '6,95\n'
      '1,57\n'
      '1,11\n'
      '3,99\n'
      '2,99\n'
      'DEBIT MASTERCARD\n'
      'AO000000041010\n'
      '526567040029716\n'
      'P400Plus-807147415\n'
      'Chip contactless\n'
      'mCstandarddebit\n'
      '0,89\n'
      '4,99\n'
      '52,49\n'
      'c79y001789305600106\n'
      '52,49\n'
      '13/09/2026\n'
      '15:20:01\n'
      'Incl\n'
      '2,99\n'
      '49,50\n'
      '52,49\n'
      'O87339\n'
      '*****5135\n'
      '€ 52,49',
  expectedTotal: 52.49,
  // Descriptions must all be present; exact price pairing is verified
  // on-device against the paper receipt (see issue thread).
  expectedItems: [],
  // Product words that must appear across item descriptions (grouping
  // may join them; fragments below are the minimum bar).
  expectedContains: [
    'alzata',
    'disney palla di nat',
    'figura led',
    'legno',
    'mini matters',
    'elbow grease',
    'detersivo piatti',
    'colorare',
    'harry potter',
    'mosaico',
    'lavagnetta',
  ],
  // Words that must NEVER appear in items (trailer/codes).
  expectedAbsent: [
    'Auth',
    'DOCUMENTO',
    'TOTALE',
    'Mastercard',
    'contactless',
    'arrivederci',
  ],
  // Prices live in the tail block without row geometry in this
  // fixture (no boxes): sum cannot be proven here.
  expectSumOk: false,
);

const allFixtures = [fenzaFixture, butcherFixture, actionFixture];
