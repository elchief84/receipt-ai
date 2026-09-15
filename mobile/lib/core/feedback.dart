/// Feedback: user corrections stored for future retraining, never online.
library;

import 'dart:convert';
import 'dart:io';

class FeedbackEntry {
  FeedbackEntry({
    required this.originalCategory,
    required this.correctedCategory,
    required this.merchantNormalized,
    required this.total,
    required this.modelVersion,
    required this.timestamp,
    this.itemDescription,
  });
  final String originalCategory;
  final String correctedCategory;
  final String merchantNormalized;
  final double total;
  final String modelVersion;
  final DateTime timestamp;

  /// Set for per-item corrections (originalCategory 'unknown' when the
  /// model couldn't decide). Null for transaction-level corrections.
  final String? itemDescription;

  Map<String, dynamic> toJson() => {
    'original_category': originalCategory,
    'corrected_category': correctedCategory,
    'merchant_normalized': merchantNormalized,
    'total': total,
    'model_version': modelVersion,
    'timestamp': timestamp.toIso8601String(),
    if (itemDescription != null) 'item_description': itemDescription,
  };

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
    originalCategory: json['original_category'] as String,
    correctedCategory: json['corrected_category'] as String,
    merchantNormalized: json['merchant_normalized'] as String,
    total: (json['total'] as num).toDouble(),
    modelVersion: json['model_version'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    // Old log files predate item corrections.
    itemDescription: json['item_description'] as String?,
  );
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

/// File-backed log: one JSON object per line, local only, never uploaded.
class FileFeedbackLog implements FeedbackLog {
  FileFeedbackLog(this.file) {
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        _entries.add(
          FeedbackEntry.fromJson(json.decode(trimmed) as Map<String, dynamic>),
        );
      }
    }
  }

  final File file;
  final List<FeedbackEntry> _entries = [];

  @override
  void record(FeedbackEntry entry) {
    _entries.add(entry);
    file.writeAsStringSync('${json.encode(entry.toJson())}\n',
        mode: FileMode.append);
  }

  @override
  List<FeedbackEntry> get entries => List.unmodifiable(_entries);
}
