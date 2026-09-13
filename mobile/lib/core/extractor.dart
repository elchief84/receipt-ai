/// Transaction extraction from Italian OCR text (regex, no ML).
/// Item segmentation lives in receipt_layout.dart; this file keeps
/// merchant/date/total extraction plus a thin segmentItems adapter.
library;

import 'dart:ui' show Rect;

import 'receipt_layout.dart';
import 'receipt_text.dart' as t;

export 'receipt_layout.dart' show SegmentedItem;

class TransactionDraft {
  TransactionDraft({
    required this.merchantRaw,
    required this.date,
    required this.total,
    required this.currency,
    required this.ocrText,
  });
  final String merchantRaw;
  final String date;
  final double total;
  final String currency;
  final String ocrText;
}

class TransactionExtractor {
  static final _date = RegExp(r'(\d{2})[/\-.](\d{2})[/\-.](\d{4})');
  static const _months = {
    'gennaio': '01',
    'febbraio': '02',
    'marzo': '03',
    'aprile': '04',
    'maggio': '05',
    'giugno': '06',
    'luglio': '07',
    'agosto': '08',
    'settembre': '09',
    'ottobre': '10',
    'novembre': '11',
    'dicembre': '12',
  };
  static final _dateWords = RegExp(
    r'(\d{1,2})\s+(gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)\s+(\d{4})',
    caseSensitive: false,
  );

  TransactionDraft extract(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final merchantRaw = lines.isNotEmpty ? lines.first : '';

    var date = '';
    final dateMatch = _date.firstMatch(ocrText);
    if (dateMatch != null) {
      date =
          '${dateMatch.group(1)}/${dateMatch.group(2)}/${dateMatch.group(3)}';
    } else {
      final wordsMatch = _dateWords.firstMatch(ocrText);
      if (wordsMatch != null) {
        final day = wordsMatch.group(1)!.padLeft(2, '0');
        final month = _months[wordsMatch.group(2)!.toLowerCase()]!;
        date = '$day/$month/${wordsMatch.group(3)}';
      }
    }

    return TransactionDraft(
      merchantRaw: merchantRaw,
      date: date,
      total: _findTotal(lines),
      currency: 'EUR',
      ocrText: ocrText,
    );
  }

  /// Last total-keyword line wins (receipts put TOTALE at the bottom);
  /// SUBTOTALE lines are ignored; a bare TOTALE reads the next line.
  /// Fallback with no usable keyword amount (OCR ate it): last amount of
  /// the receipt, skipping RESTO lines. A wrong guess beats a 0.00 lie.
  static double _findTotal(List<String> lines) {
    var total = 0.0;
    var found = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final key = t.keywordForm(line);
      if (!t.totalKeywordPattern.hasMatch(key) ||
          t.subtotalPattern.hasMatch(key)) {
        continue;
      }
      found = true;
      final amounts = t.amountPattern
          .allMatches(line)
          .map((m) => t.parseItalianAmount(m.group(1)!))
          .toList();
      if (amounts.isNotEmpty) {
        total = amounts.last;
      } else {
        // Window of exactly 1: the classic "TOTALE\n13,60" layout only.
        final next = _firstAmountInNextLines(lines, i + 1, 1);
        if (next != null) total = next;
      }
    }
    if (!found || total == 0.0) {
      final fallback = _lastAmountSkippingResto(lines);
      if (fallback != null) return fallback;
    }
    return total;
  }

  static double? _firstAmountInNextLines(
    List<String> lines,
    int from,
    int count,
  ) {
    for (var i = from; i < lines.length && i < from + count; i++) {
      final match = t.amountPattern.firstMatch(lines[i]);
      if (match != null) return t.parseItalianAmount(match.group(1)!);
    }
    return null;
  }

  static double? _lastAmountSkippingResto(List<String> lines) {
    for (var i = lines.length - 1; i >= 0; i--) {
      if (t.restoPattern.hasMatch(lines[i].toUpperCase())) continue;
      final amounts = t.amountPattern
          .allMatches(lines[i])
          .map((m) => t.parseItalianAmount(m.group(1)!))
          .toList();
      if (amounts.isNotEmpty) return amounts.last;
    }
    return null;
  }

  /// Thin adapter over ReceiptLayoutParser (sum unknown here).
  static List<SegmentedItem> segmentItems(
    List<String> lines, [
    List<Rect?>? boxes,
  ]) {
    return ReceiptLayoutParser.parse(lines, boxes, 0).items;
  }
}
