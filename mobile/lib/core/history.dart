/// Session history of classified transactions (in-memory for MVP).
/// Powers the Summary screen answering "how did I spend my money?".
library;

import 'pipeline.dart';

class HistoryLog {
  final List<TransactionResult> _results = [];

  void add(TransactionResult result) => _results.add(result);

  List<TransactionResult> get results => List.unmodifiable(_results);

  /// Total per category, descending.
  Map<String, double> totalsByCategory() {
    final totals = <String, double>{};
    for (final r in _results) {
      totals[r.category] = (totals[r.category] ?? 0) + r.total;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }
}
