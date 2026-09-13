/// Shared pure text helpers for receipt parsing (single source of truth).
/// Used by both the transaction extractor and the layout parser.
library;

/// Amount like 10,60 / 10.60 / 1.234,56. Trailing (?!\d) excludes dotted
/// phone numbers ("0564.620438") and matricola codes.
final amountPattern = RegExp(r'(\d[\d.]*(?:[,.]\d{2}))(?!\d)');

double parseItalianAmount(String raw) {
  // "1.234,56" -> 1234.56 ; "10.60" -> 10.60 ; "10,60" -> 10.60
  if (raw.contains(',')) {
    return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.')) ??
        0.0;
  }
  return double.tryParse(raw) ?? 0.0;
}

final totalKeywordPattern = RegExp(
  r'\b(TOTALE|TOTAL|IMPORTO)\b',
  caseSensitive: false,
);

final subtotalPattern = RegExp(r'SUB\s*TOT', caseSensitive: false);

final restoPattern =
    RegExp(r'\b(RESTO|RESTA|CAMBIO|CHANGE)\b', caseSensitive: false);

/// OCR-confusion map used ONLY for keyword detection, never for amounts.
String keywordForm(String line) => line
    .toUpperCase()
    .replaceAll('0', 'O')
    .replaceAll('1', 'I')
    .replaceAll('4', 'A')
    .replaceAll('3', 'E')
    .replaceAll('5', 'S');

/// Letter tokens of a line (digits dropped).
List<String> letterTokens(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .split(' ')
      .where((t) => t.isNotEmpty && int.tryParse(t) == null)
      .toList();
}

/// Meta/header vocabulary: lines carrying one of these tokens are
/// section scaffolding, never products. Token-based, never substring:
/// "protettiva" must not match "iva".
const metaWords = {
  'riepilogo',
  'ordine',
  'invia',
  'venduto',
  'consegnato',
  'reso',
  'metodo',
  'pagamento',
  'mastercard',
  'torna',
  'aiuto',
  'subtotale',
  'totale',
  'spedizione',
  'iva',
  'condizioni',
  'privacy',
  'stampa',
  'italia',
  'grazie',
  'arrivederci',
  'cassa',
  'scontr',
  'resto',
  'contanti',
  'contante',
  'carta',
  'euro',
  'telefono',
  'cliente',
  'prezzo', // price labels ("Prezzo( €)"), never products
  'rt', // matricola line, never a product
  'documento',
  'commerciale',
  'numero',
  'articoli', // "NUMERO DI ARTICOLI" trailer (product bodies use ARTICOLI header instead — see bodyStartMarkers)
  'server',
  'modalita',
  'tipo',
  'auth',
};

bool isMetaLine(String line) {
  final tokens = line
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .split(' ')
      .where((t) => t.isNotEmpty)
      .toSet();
  return metaWords.any(tokens.contains);
}

/// Payment-only words: a same-line remainder made solely of these is
/// not a product description ("DI CUI IVA 1,60", "EURO 50,00").
const priceStopTokens = {
  'totale',
  'total',
  'subtotale',
  'importo',
  'resto',
  'resta',
  'cambio',
  'change',
  'contanti',
  'contante',
  'euro',
  'iva',
  'cui',
  'di',
};
/// Body-start markers of the product section in RT receipts.
/// Section headers are short (≤ 3 tokens): product lines mentioning
/// "prodotto" ("ventosa prodotto lungo...") must not match.
/// NOTE: "Subtotale articoli:" and "NUMERO DI ARTICOLI" also carry
/// articol-tokens — callers must skip trailer/boundary lines first.
bool isBodyStart(String line) {
  final tokens = letterTokens(line);
  if (tokens.length > 3) return false;
  return tokens.any(
    (t) =>
        t.startsWith('descriz') ||
        t == 'reparto' ||
        t.startsWith('articol') ||
        t == 'prodotto' ||
        t == 'merce',
  );
}
