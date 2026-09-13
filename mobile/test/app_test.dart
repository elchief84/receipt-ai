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

ReceiptPipeline testPipeline() => ReceiptPipeline(
  extractor: TransactionExtractor(),
  normalizer: MerchantNormalizer({
    'conad superstore': 'supermarket',
    'eni': 'fuel',
    'amazon': 'ecommerce',
    'farmacia comunale': 'pharmacy',
    'pizzeria da michele': 'restaurant',
  }),
  classifier: KeywordClassifier(),
);

void main() {
  testWidgets('home shows actions and samples, sample opens result', (
    tester,
  ) async {
    final feedback = InMemoryFeedbackLog();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          pipeline: testPipeline(),
          ocr: FakeOcrEngine(''),
          feedback: feedback,
          history: HistoryLog(),
        ),
      ),
    );

    expect(find.text('Expense Classifier'), findsOneWidget);
    expect(find.byKey(const Key('takePhoto')), findsOneWidget);
    expect(find.byKey(const Key('chooseImage')), findsOneWidget);
    expect(find.byKey(const Key('sample-Conad')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sample-Conad')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('total')), findsOneWidget);
    expect(find.byKey(const Key('category')), findsOneWidget);
    expect(find.byKey(const Key('confidence')), findsOneWidget);
  });

  testWidgets('correct and change-category record feedback', (tester) async {    final feedback = InMemoryFeedbackLog();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          pipeline: testPipeline(),
          ocr: FakeOcrEngine(''),
          feedback: feedback,
          history: HistoryLog(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('sample-Conad')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('correct')));
    await tester.pump();
    expect(feedback.entries, hasLength(1));
    expect(feedback.entries.first.originalCategory, isNotEmpty);

    await tester.tap(find.byKey(const Key('changeCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-shopping')));
    await tester.pumpAndSettle();
    expect(feedback.entries, hasLength(2));
    expect(feedback.entries.last.correctedCategory, 'shopping');
  });

  testWidgets('macelleria sample shows groceries item details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          pipeline: testPipeline(),
          ocr: FakeOcrEngine(''),
          feedback: InMemoryFeedbackLog(),
          history: HistoryLog(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('sample-Macelleria')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('itemDetail-0')), findsOneWidget);
    expect(find.textContaining('groceries'), findsWidgets);
  });

  testWidgets('unsupported document shows error, no result', (tester) async {
    const unsupported = (
      name: 'Amazon',
      text: 'Riepilogo dell\'ordine\nVenduto da: Amazon.it\nTotale: 10,00',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          pipeline: testPipeline(),
          ocr: FakeOcrEngine(''),
          feedback: InMemoryFeedbackLog(),
          history: HistoryLog(),
          samples: const [unsupported],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('sample-Amazon')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Documento non supportato'), findsOneWidget);
    expect(find.byKey(const Key('total')), findsNothing);
  });
}

