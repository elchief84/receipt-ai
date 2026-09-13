import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/classify.dart';
import 'package:receipt_ai/core/extractor.dart';
import 'package:receipt_ai/core/feedback.dart';
import 'package:receipt_ai/core/history.dart';
import 'package:receipt_ai/core/merchant.dart';
import 'package:receipt_ai/core/ocr.dart';
import 'package:receipt_ai/core/pipeline.dart';
import 'package:receipt_ai/features/home_screen.dart';
import 'package:receipt_ai/features/samples.dart';

/// Full asset plug: real gazetteer + real trained model from T2.
void main() {
  testWidgets('real assets classify Conad sample as groceries', (tester) async {
    final normalizer = await MerchantNormalizer.fromAssets(
      'assets/merchant_gazetteer.csv',
    );
    final classifier = await JsonLogisticClassifier.fromAssets(
      'assets/classifier.json',
      'logreg-v1',
    );
    final pipeline = ReceiptPipeline(
      extractor: TransactionExtractor(),
      normalizer: normalizer,
      classifier: classifier,
    );
    final conad = sampleReceipts.firstWhere((s) => s.name == 'Conad');
    final result = pipeline.run(conad.text);
    expect(result.merchantType, 'supermarket');
    expect(result.category, 'groceries');
    expect(result.total, 10.60);
  });

  testWidgets('summary shows corrected totals after change', (tester) async {
    final history = HistoryLog();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          pipeline: ReceiptPipeline(
            extractor: TransactionExtractor(),
            normalizer: MerchantNormalizer({'conad': 'supermarket'}),
            classifier: KeywordClassifier(),
          ),
          ocr: FakeOcrEngine(''),
          feedback: InMemoryFeedbackLog(),
          history: history,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('sample-Conad')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('changeCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-shopping')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('total')))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('summary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-shopping')), findsOneWidget);
    expect(find.text('€10.60'), findsOneWidget);
  });
}
