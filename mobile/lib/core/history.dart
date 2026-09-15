/// Session history of classified transactions (in-memory for MVP).
/// Powers the Summary screen answering "how did I spend my money?".
library;

import 'pipeline.dart';

class HistoryLog {
  final List<TransactionResult> _results = [];

  void add(TransactionResult result) => _results.add(result);

  List<TransactionResult> get results => List.unmodifiable(_results);

  /// Total per category, descending.
  Map<String, double> totalsByCategory() {    final totals = <String, double>{};
    for (final r in _results) {
      totals[r.category] = (totals[r.category] ?? 0) + r.total;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  /// Item rows the model couldn't classify, across all results.
  /// Count only (no money): transaction totals already account for every
  /// euro under the transaction category — showing item money here would
  /// double-count. A data-quality signal driving corrections (ADR-0010).
  int get unknownItemCount => _results
      .expand((r) => r.itemDetails)
      .where((d) => d.isUnknown)
      .length;
}
