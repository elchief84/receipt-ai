import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receipt_ai/core/classify.dart';
import 'package:receipt_ai/core/extractor.dart';
import 'package:receipt_ai/core/feedback.dart';
import 'package:receipt_ai/core/history.dart';
import 'package:receipt_ai/core/merchant.dart';
import 'package:receipt_ai/core/ocr.dart';
import 'package:receipt_ai/core/pipeline.dart';
import 'package:receipt_ai/features/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final normalizer = await _loadNormalizer();
  final classifier = await _loadClassifier();
  FeedbackLog feedback;
  try {
    final dir = await getApplicationDocumentsDirectory();
    feedback = FileFeedbackLog(File('${dir.path}/feedback.jsonl'));
  } catch (_) {
    feedback = InMemoryFeedbackLog();
  }
  runApp(
    ReceiptApp(
      pipeline: ReceiptPipeline(
        extractor: TransactionExtractor(),
        normalizer: normalizer,
        classifier: classifier,
      ),
      ocr: MlKitOcrEngine(),
      feedback: feedback,
      history: HistoryLog(),
    ),
  );
}

Future<MerchantNormalizer> _loadNormalizer() async {
  try {
    return await MerchantNormalizer.fromAssets('assets/merchant_gazetteer.csv');
  } catch (_) {
    return MerchantNormalizer(const {});
  }
}

Future<Classifier> _loadClassifier() async {
  try {
    return await JsonLogisticClassifier.fromAssets(
      'assets/classifier.json',
      'logreg-v1',
    );
  } catch (_) {
    // Asset absent (or first run): keyword fallback keeps the demo working.
    return KeywordClassifier();
  }
}

class ReceiptApp extends StatelessWidget {
  const ReceiptApp({
    super.key,
    required this.pipeline,
    required this.ocr,
    required this.feedback,
    required this.history,
  });

  final ReceiptPipeline pipeline;
  final OcrEngine ocr;
  final FeedbackLog feedback;
  final HistoryLog history;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Classifier',
      theme: ThemeData(useMaterial3: true),
      home: HomeScreen(
        pipeline: pipeline,
        ocr: ocr,
        feedback: feedback,
        history: history,
      ),
    );
  }
}
