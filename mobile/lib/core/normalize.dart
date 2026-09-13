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
String normalizeName(String raw) {
  var text = raw.toLowerCase();
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
