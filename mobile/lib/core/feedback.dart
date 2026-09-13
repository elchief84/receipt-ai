/// Feedback: user corrections stored for future retraining, never online.
/// T3 keeps it in memory; T4 adds file persistence behind the same seam.
library;

class FeedbackEntry {
  FeedbackEntry({
    required this.originalCategory,
    required this.correctedCategory,
    required this.merchantNormalized,
    required this.total,
    required this.modelVersion,
    required this.timestamp,
  });
  final String originalCategory;
  final String correctedCategory;
  final String merchantNormalized;
  final double total;
  final String modelVersion;
  final DateTime timestamp;
}

abstract class FeedbackLog {
  void record(FeedbackEntry entry);
  List<FeedbackEntry> get entries;
}

class InMemoryFeedbackLog implements FeedbackLog {
  final List<FeedbackEntry> _entries = [];

  @override
  void record(FeedbackEntry entry) => _entries.add(entry);

  @override
  List<FeedbackEntry> get entries => List.unmodifiable(_entries);
}
