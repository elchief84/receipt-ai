import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/classify.dart';
import 'package:receipt_ai/core/extractor.dart';
import 'package:receipt_ai/core/merchant.dart';
import 'package:receipt_ai/core/pipeline.dart';

ReceiptPipeline keywordPipeline() => ReceiptPipeline(
  extractor: TransactionExtractor(),
  normalizer: MerchantNormalizer({'conad': 'supermarket'}),
  classifier: KeywordClassifier(),
);

void main() {
  test('informative lines get labels, junk stays unlabeled', () {
    const ocr =
        'CONAD\n12/09/2026\n\nLATTE INTERO 1.49\n41\nE\nStampa\n\nTOTALE 10,60';
    final result = keywordPipeline().run(ocr);
    final labeled = result.itemDetails.map((d) => d.description).toList();
    expect(labeled.any((d) => d.contains('LATTE')), isTrue);
    expect(labeled.any((d) => d == '41' || d == 'E' || d == 'Stampa'), isFalse);
  });

  test('item label carries its own category and confidence', () {
    const ocr = 'CONAD\n12/09/2026\n\nPANE 2,00\n\nTOTALE 2,00';
    final result = keywordPipeline().run(ocr);
    expect(result.itemDetails, isNotEmpty);
    expect(result.itemDetails.first.category, 'groceries');
  });

  test('empty details when receipt has no item lines', () {
    const ocr = 'CONAD\n12/09/2026\n\nTOTALE 10,60';
    expect(keywordPipeline().run(ocr).itemDetails, isEmpty);
  });

  test('single priceless item inherits the transaction total', () {
    const ocr = 'FARMACIA\nDescrizione\nDENTIFRICIO MENTA\nDI CUI IVA\nTOTALE 13,60';
    final result = keywordPipeline().run(ocr);
    expect(result.itemDetails, hasLength(1));
    expect(result.itemDetails.first.price, 13.60);
  });
}
