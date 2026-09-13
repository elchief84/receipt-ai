import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/normalize.dart';

void main() {
  test('strips legal forms and address like Python', () {
    expect(
      normalizeName('Conad Superstore S.r.l. - Via Roma 12'),
      'conad superstore',
    );
  });

  test('deaccents and lowercases', () {
    expect(normalizeName('FARMACÌA Comunale'), 'farmacia comunale');
  });

  test('collapses spaces and punctuation', () {
    expect(
      normalizeName('  Eni,  Stazione  di  servizio! '),
      'eni stazione di servizio',
    );
  });

  test('merchant types closed list', () {
    expect(
      merchantTypes,
      containsAll([
        'supermarket',
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
      ]),
    );
  });

  test('default category mapping', () {
    expect(defaultCategoryForMerchantType('supermarket'), 'groceries');
    expect(defaultCategoryForMerchantType('electronics'), 'technology');
    expect(defaultCategoryForMerchantType('ecommerce'), 'shopping');
    expect(defaultCategoryForMerchantType('unknown_type'), 'other');
  });
}
