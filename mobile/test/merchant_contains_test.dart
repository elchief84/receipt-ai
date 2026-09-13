import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/merchant.dart';

void main() {
  final normalizer = MerchantNormalizer({
    'conad superstore': 'supermarket',
    'amazon': 'ecommerce',
  });

  test('single-letter lines never match via contains', () {
    expect(normalizer.findInLines(['E', 'X', '2']), isNull);
  });

  test('token overlap still catches buried merchant', () {
    final hit = normalizer.findInLines([
      'Riepilogo',
      'E',
      'Venduto da: Amazon.it',
    ]);
    expect(hit!.normalizedName, 'amazon');
  });

  test('short legit merchant token still matches', () {
    final n = MerchantNormalizer({'eni': 'fuel'});
    expect(n.normalize('ENI Stazione').merchantType, 'fuel');
  });
}
