import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

LineGeometry _g(double top, {double? confidence}) => LineGeometry(
  Rect.fromLTWH(0, top, 200, 18),
  confidence: confidence,
);
LineGeometry _price(double top, {double? confidence}) => LineGeometry(
  Rect.fromLTWH(250, top, 300, top + 18),
  confidence: confidence,
);

void main() {
  test('item confidence is the weakest contributing line, flagged below threshold',
      () {
    final lines = [
      'CONAD SUPERSTORE',
      'P.IVA 01234567890',
      'ARTICOLI',
      'LATTE INTERO', // weak OCR line
      '1,49',
      'PASTA BARILLA',
      '2,00',
      'TOTALE COMPLESSIVO 3,49',
    ];
    final geoms = <LineGeometry?>[
      _g(0, confidence: 0.99),
      _g(25, confidence: 0.99),
      _g(50, confidence: 0.99),
      _g(80, confidence: 0.4),
      _price(80, confidence: 0.9),
      _g(120, confidence: 0.95),
      _price(120, confidence: 0.95),
      _g(160, confidence: 0.99),
    ];
    final layout = ReceiptLayoutParser.parseLines(lines, geoms, 3.49);
    final latte = layout.items.firstWhere((e) => e.description == 'LATTE INTERO');
    final pasta = layout.items.firstWhere((e) => e.description == 'PASTA BARILLA');
    expect(latte.confidence, 0.4);
    expect(latte.isLowConfidence, isTrue);
    expect(pasta.confidence, 0.95);
    expect(pasta.isLowConfidence, isFalse);
    expect(layout.lowConfidenceCount, 1);
  });

  test('unknown confidence is never flagged as low', () {
    final lines = [
      'CONAD SUPERSTORE',
      'P.IVA 01234567890',
      'ARTICOLI',
      'LATTE INTERO',
      '1,49',
      'TOTALE COMPLESSIVO 1,49',
    ];
    final geoms = <LineGeometry?>[
      _g(0),
      _g(25),
      _g(50),
      _g(80),
      _price(80),
      _g(120),
    ];
    final layout = ReceiptLayoutParser.parseLines(lines, geoms, 1.49);
    expect(layout.items.single.confidence, isNull);
    expect(layout.items.single.isLowConfidence, isFalse);
    expect(layout.lowConfidenceCount, 0);
  });
}
