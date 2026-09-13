import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';

List<String> _lines(String ocr) =>
    ocr.split('\n').map((l) => l.trim()).toList();

void main() {
  test('bare price claims all preceding orphan lines', () {
    const ocr = 'SHOP\nXIAOMI POCO C85\nSmartphone 6GB\n129,90';
    final items = TransactionExtractor.segmentItems(_lines(ocr));
    expect(items, hasLength(1));
    expect(items.first.description, 'XIAOMI POCO C85 Smartphone 6GB');
    expect(items.first.price, 129.90);
  });

  test('inline price claims short fragment lines below', () {
    const ocr = 'SHOP\nMOMENT 8,60\nplast ica\nTOTALE';
    final items = TransactionExtractor.segmentItems(_lines(ocr));
    expect(items, hasLength(1));
    expect(items.first.description, 'MOMENT plast ica');
    expect(items.first.price, 8.60);
  });

  test('meta lines stop the backward walk', () {
    const ocr = 'SHOP\nXIAOMI POCO\nVenduto da X\n129,90';
    final items = TransactionExtractor.segmentItems(_lines(ocr));
    expect(items, hasLength(1));
    expect(items.first.description, 'XIAOMI POCO');
  });

  test('bare price with no usable desc is dropped, not empty', () {
    const ocr = 'SHOP\nPrezzo\n13,60\nTOTALE';
    expect(TransactionExtractor.segmentItems(_lines(ocr)), isEmpty);
  });
}
