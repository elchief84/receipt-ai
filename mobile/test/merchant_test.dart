import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/merchant.dart';

void main() {
  final normalizer = MerchantNormalizer({
    'conad superstore': 'supermarket',
    'eni': 'fuel',
    'amazon': 'ecommerce',
  });

  test('exact gazetteer hit', () {
    final m = normalizer.normalize('Conad Superstore S.r.l.');
    expect(m.normalizedName, 'conad superstore');
    expect(m.merchantType, 'supermarket');
  });

  test('contains-match on longer raw name', () {
    final m = normalizer.normalize('ENI Stazione di Servizio Roma');
    expect(m.merchantType, 'fuel');
  });

  test('unknown merchant falls back to other', () {
    final m = normalizer.normalize('Negozio Mai Visto XYZ');
    expect(m.merchantType, 'other');
  });
}
