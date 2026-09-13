import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/classify.dart';

/// Parity: the Dart logistic port must agree with sklearn on composed data.
/// Model asset is the one trained in T2 (ml/data/exp2/classifier.json).
void main() {
  late Map<String, dynamic> model;

  setUpAll(() {
    final file = File('../ml/data/exp2/classifier.json');
    model = json.decode(file.readAsStringSync());
  });

  ClassificationInput input(String merchant, String type, String text) =>
      ClassificationInput(
        merchantNormalized: merchant,
        merchantType: type,
        ocrText: text,
        items: const [],
      );

  test('json logistic classifies supermarket receipt as groceries', () {
    final clf = JsonLogisticClassifier.fromMap(model, 'logreg-v1');
    final res = clf.classify(
      input('conad superstore', 'supermarket', 'latte pasta pane conad'),
    );
    expect(res.category, 'groceries');
    expect(res.confidence, inInclusiveRange(0.0, 1.0));
  });

  test('confidence levels follow configured thresholds', () {
    expect(levelFor(0.9), ConfidenceLevel.high);
    expect(levelFor(0.5), ConfidenceLevel.medium);
    expect(levelFor(0.1), ConfidenceLevel.low);
  });

  test('keyword fallback never crashes and stays in taxonomy', () {
    final clf = KeywordClassifier();
    const categories = [
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
    final res = clf.classify(input('xyz', 'other', 'pane latte supermercato'));
    expect(categories, contains(res.category));
    expect(res.category, 'groceries');
  });
}
