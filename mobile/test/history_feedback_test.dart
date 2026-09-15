import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/classify.dart';
import 'package:receipt_ai/core/feedback.dart';
import 'package:receipt_ai/core/history.dart';
import 'package:receipt_ai/core/pipeline.dart';

TransactionResult result(String category, double total) => TransactionResult(
  merchantRaw: 'Conad',
  merchantNormalized: 'conad',
  merchantType: 'supermarket',
  date: '12/09/2026',
  total: total,
  currency: 'EUR',
  category: category,
  confidence: 0.9,
  modelVersion: 'test',
  ocrText: '',
  items: const [],
);

FeedbackEntry entry(String corrected) => FeedbackEntry(
  originalCategory: 'groceries',
  correctedCategory: corrected,
  merchantNormalized: 'conad',
  total: 10.0,
  modelVersion: 'test',
  timestamp: DateTime.utc(2026, 9, 13),
);

void main() {
  test('history totals group by category descending', () {
    final history = HistoryLog();
    history.add(result('groceries', 10.0));
    history.add(result('restaurants', 30.0));
    history.add(result('groceries', 5.0));
    final totals = history.totalsByCategory();
    expect(totals.keys.toList(), ['restaurants', 'groceries']);
    expect(totals['groceries'], 15.0);
  });

  test('file feedback log roundtrips entries', () async {    final dir = await Directory.systemTemp.createTemp('feedback_test');
    final file = File('${dir.path}/feedback.jsonl');
    final log = FileFeedbackLog(file);
    log.record(entry('shopping'));
    final reopened = FileFeedbackLog(file);
    expect(reopened.entries, hasLength(1));
    expect(reopened.entries.first.correctedCategory, 'shopping');
    expect(reopened.entries.first.timestamp, DateTime.utc(2026, 9, 13));
    await dir.delete(recursive: true);
  });

  test('unknown items are counted, never silently bucketed', () {
    TransactionResult withItems(List<ItemClassification> details) =>
        TransactionResult(
          merchantRaw: 'Conad',
          merchantNormalized: 'conad',
          merchantType: 'supermarket',
          date: '12/09/2026',
          total: 10.0,
          currency: 'EUR',
          category: 'groceries',
          confidence: 0.9,
          modelVersion: 'test',
          ocrText: '',
          items: const [],
          itemDetails: details,
        );
    const labeled = ItemClassification(
      description: 'pane',
      category: 'groceries',
      confidence: 0.9,
    );
    const unlabeled = ItemClassification(
      description: 'scontrino parlante',
      category: null,
      confidence: 0.2,
    );
    final history = HistoryLog();
    expect(history.unknownItemCount, 0);
    history.add(withItems(const [labeled, unlabeled]));
    history.add(withItems(const [labeled]));
    expect(history.unknownItemCount, 1);
  });

  test('item correction feedback roundtrips description', () async {
    final dir = await Directory.systemTemp.createTemp('feedback_item_test');
    final file = File('${dir.path}/feedback.jsonl');
    final log = FileFeedbackLog(file);
    log.record(
      FeedbackEntry(
        originalCategory: 'unknown',
        correctedCategory: 'technology',
        merchantNormalized: 'amazon',
        total: 29.99,
        modelVersion: 'logreg-v1',
        timestamp: DateTime.utc(2026, 9, 14),
        itemDescription: 'cuffie bluetooth',
      ),
    );
    final reopened = FileFeedbackLog(file);
    expect(reopened.entries, hasLength(1));
    expect(reopened.entries.first.originalCategory, 'unknown');
    expect(reopened.entries.first.itemDescription, 'cuffie bluetooth');
    await dir.delete(recursive: true);
  });

  test('old feedback files without item description still load', () async {
    final dir = await Directory.systemTemp.createTemp('feedback_compat_test');
    final file = File('${dir.path}/feedback.jsonl');
    await file.writeAsString(
      '{"original_category":"groceries","corrected_category":"shopping",'
      '"merchant_normalized":"conad","total":10.0,"model_version":"test",'
      '"timestamp":"2026-09-13T00:00:00.000Z"}\n',
    );
    final log = FileFeedbackLog(file);
    expect(log.entries, hasLength(1));
    expect(log.entries.first.itemDescription, isNull);
    await dir.delete(recursive: true);
  });
}
