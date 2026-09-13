/// Normalization port — must match ml/datasets/normalize.py exactly.
/// Tokenizer spec: normalize_name+split-v1.
library;

const merchantTypes = [
  'supermarket',
  'food_shop',
  'fuel',
  'pharmacy',
  'restaurant',
  'clothes',
  'home_store',
  'electronics',
  'hotel',
  'transport_service',
  'services',
  'ecommerce',
  'other',
];

const expenseCategories = [
  'groceries',
  'restaurants',
  'transport',
  'health',
  'shopping',
  'technology',
  'leisure_travel',
  'services',
  'other',
];

const _merchantTypeToCategory = {
  'supermarket': 'groceries',
  'food_shop': 'groceries',
  'fuel': 'transport',
  'pharmacy': 'health',
  'restaurant': 'restaurants',
  'clothes': 'shopping',
  'home_store': 'shopping',
  'electronics': 'technology',
  'hotel': 'leisure_travel',
  'transport_service': 'transport',
  'services': 'services',
  'ecommerce': 'shopping',
  'other': 'other',
};

String defaultCategoryForMerchantType(String merchantType) =>
    _merchantTypeToCategory[merchantType] ?? 'other';

const _deaccent = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Port of Python normalize_name: lowercase → deaccent → strip legal
/// forms/addresses → drop punctuation → collapse → drop digit tokens.
String normalizeName(String raw) {  var text = raw.toLowerCase();
  text = text.split('').map((c) => _deaccent[c] ?? c).join();
  text = text.replaceAll(
    RegExp(r'\b(s\.?r\.?l\.?|s\.?p\.?a\.?|s\.?a\.?s\.?|s\.?n\.?c\.?)\b'),
    '',
  );
  text = text.replaceAll(RegExp(r'\s-\s.*$'), '');
  text = text.replaceAll(RegExp(r'\bvia\b.*$'), '');
  text = text.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text
      .split(' ')
      .where((t) => t.isNotEmpty && int.tryParse(t) == null)
      .join(' ');
  return text;
}

/// Italian stopwords — must match ml.datasets.normalize.IT_STOPWORDS.
/// Tokenizer spec stopwords-v2.
const itStopwords = {
  'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una',
  'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
  'del', 'dello', 'della', 'dei', 'degli', 'delle',
  'al', 'allo', 'alla', 'ai', 'agli', 'alle',
  'dal', 'dallo', 'dalla', 'dai', 'dagli', 'dalle',
  'nel', 'nello', 'nella', 'nei', 'negli', 'nelle',
  'sul', 'sullo', 'sulla', 'sui', 'sugli', 'sulle',
  'col', 'coi', 'che', 'se', 'come', 'piu', 'meno',
  'non', 'si', 'ci', 'ne', 'mio', 'tuo', 'suo', 'nostro', 'vostro',
  'questo', 'questa', 'questi', 'queste', 'quello', 'quella',
  'sono', 'hai', 'hanno', 'siamo', 'siete', 'era', 'erano', 'stato',
  'l', 'e', 'ed', 'ma', 'o', 'od', 'anche', 'solo', 'gia',
};

/// Port of Python tokenize: normalize → split → drop 1-char → drop stopwords.
List<String> tokenize(String text) => normalizeName(text)
    .split(' ')
    .where((t) => t.length >= 2 && !itStopwords.contains(t))
    .toList();
