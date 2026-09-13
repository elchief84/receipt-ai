/// Pipeline facade: OCR text -> TransactionResult.
/// Single seam the UI and T4 summary walk through.
library;

import 'classify.dart';
import 'extractor.dart';
import 'merchant.dart';

class TransactionResult {
  TransactionResult({
    required this.merchantRaw,
    required this.merchantNormalized,
    required this.merchantType,
    required this.date,
    required this.total,
    required this.currency,
    required this.category,
    required this.confidence,
    required this.modelVersion,
    required this.ocrText,
    required this.items,
  });
  final String merchantRaw;
  final String merchantNormalized;
  final String merchantType;
  final String date;
  final double total;
  final String currency;
  final String category;
  final double confidence;
  final String modelVersion;
  final String ocrText;
  final List<String> items;

  TransactionResult copyWith({String? category}) => TransactionResult(
    merchantRaw: merchantRaw,
    merchantNormalized: merchantNormalized,
    merchantType: merchantType,
    date: date,
    total: total,
    currency: currency,
    category: category ?? this.category,
    confidence: confidence,
    modelVersion: modelVersion,
    ocrText: ocrText,
    items: items,
  );
}

class ReceiptPipeline {
  ReceiptPipeline({
    required this.extractor,
    required this.normalizer,
    required this.classifier,
  });
  final TransactionExtractor extractor;
  final MerchantNormalizer normalizer;
  final Classifier classifier;

  TransactionResult run(String ocrText) {
    final draft = extractor.extract(ocrText);
    final lines = ocrText.split('\n').map((l) => l.trim()).toList();
    final merchant =
        normalizer.findInLines(lines) ?? normalizer.normalize(draft.merchantRaw);
    final items = _itemLines(ocrText);
    final classification = classifier.classify(
      ClassificationInput(
        merchantNormalized: merchant.normalizedName,
        merchantType: merchant.merchantType,
        ocrText: ocrText,
        items: items,
      ),
    );
    return TransactionResult(
      merchantRaw: draft.merchantRaw,
      merchantNormalized: merchant.normalizedName,
      merchantType: merchant.merchantType,
      date: draft.date,
      total: draft.total,
      currency: draft.currency,
      category: classification.category,
      confidence: classification.confidence,
      modelVersion: classification.modelVersion,
      ocrText: ocrText,
      items: items,
    );
  }

  static List<String> _itemLines(String ocrText) {
    final lines = ocrText.split('\n').map((l) => l.trim()).toList();
    if (lines.length <= 4) return const [];
    // Skip header (merchant, date) and footer (total).
    return lines.sublist(2, lines.length - 1).where((l) => l.isNotEmpty).toList();
  }
}
