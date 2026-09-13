import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('file feedback log roundtrips entries', () async {
    final dir = await Directory.systemTemp.createTemp('feedback_test');
    final file = File('${dir.path}/feedback.jsonl');
    final log = FileFeedbackLog(file);
    log.record(entry('shopping'));
    final reopened = FileFeedbackLog(file);
    expect(reopened.entries, hasLength(1));
    expect(reopened.entries.first.correctedCategory, 'shopping');
    expect(reopened.entries.first.timestamp, DateTime.utc(2026, 9, 13));
    await dir.delete(recursive: true);
  });
}
