/// Pipeline facade: OCR text -> TransactionResult.
/// Single seam the UI and T4 summary walk through.
library;

import 'classify.dart';
import 'extractor.dart';
import 'merchant.dart';
import 'normalize.dart';

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
    this.itemDetails = const [],
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

  /// Item-level labels (ADR-0007). Empty when nothing informative.
  final List<ItemClassification> itemDetails;

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
    itemDetails: itemDetails,
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
    final items = TransactionExtractor.segmentItems(lines);
    final descriptions = items.map((e) => e.description).toList();
    final classification = classifier.classify(
      ClassificationInput(
        merchantNormalized: merchant.normalizedName,
        merchantType: merchant.merchantType,
        ocrText: ocrText,
        items: descriptions,
      ),
    );
    return TransactionResult(
      merchantRaw: merchant.normalizedName.isEmpty
          ? draft.merchantRaw
          : merchant.rawName,
      merchantNormalized: merchant.normalizedName,
      merchantType: merchant.merchantType,
      date: draft.date,
      total: draft.total,
      currency: draft.currency,
      category: classification.category,
      confidence: classification.confidence,
      modelVersion: classification.modelVersion,
      ocrText: ocrText,
      items: descriptions,
      itemDetails: _withSingleItemTotal(
        _classifyItems(
          classifier,
          merchantType: merchant.merchantType,
          items: items,
        ),
        draft.total,
      ),
    );
  }

  /// Single priceless item: the whole purchase is that item, so it
  /// inherits the transaction total (Fenza case).
  static List<ItemClassification> _withSingleItemTotal(
    List<ItemClassification> details,
    double total,
  ) {
    if (details.length != 1 || details.first.price != null || total <= 0) {
      return details;
    }
    final d = details.first;
    return [
      ItemClassification(
        description: d.description,
        category: d.category,
        confidence: d.confidence,
        price: total,
      ),
    ];
  }

  /// One model call per line, same artifact. Every segmented line is
  /// shown; the label lands only at medium+ confidence (null otherwise).
  static List<ItemClassification> _classifyItems(
    Classifier classifier, {
    required String merchantType,
    required List<SegmentedItem> items,
  }) {
    final details = <ItemClassification>[];
    for (final item in items) {
      final line = item.description;
      // No informative tokens (digits/stopwords only): never a label.
      // The merchant name stays OUT of the item signal on purpose:
      // the line must earn its label alone (ADR-0001 at item level).
      if (tokenize(line).isEmpty) continue;
      final res = classifier.classify(
        ClassificationInput(
          merchantNormalized: '',
          merchantType: merchantType,
          ocrText: line,
          items: [line],
        ),
      );
      details.add(
        ItemClassification(
          description: line,
          category: res.level == ConfidenceLevel.low ? null : res.category,
          confidence: res.confidence,
          price: item.price,
        ),
      );
    }
    return details;
  }
}
