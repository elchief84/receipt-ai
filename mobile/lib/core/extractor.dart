/// Transaction extraction from Italian OCR text (regex, no ML).
library;

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
  static final _totalKeyword = RegExp(
    r'\b(TOTALE|TOTAL|IMPORTO)\b',
    caseSensitive: false,
  );
  static final _subtotal = RegExp(r'SUB\s*TOT', caseSensitive: false);
  static final _resto =
      RegExp(r'\b(RESTO|RESTA|CAMBIO|CHANGE)\b', caseSensitive: false);
  static final _amount = RegExp(r'(\d[\d.]*(?:[,.]\d{2}))');

  /// OCR-confusion map used ONLY for keyword detection, never for amounts.
  static String _keywordForm(String line) => line
      .toUpperCase()
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('4', 'A')
      .replaceAll('3', 'E')
      .replaceAll('5', 'S');

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
  /// Fallback with no keyword at all (OCR ate it): last amount of the
  /// receipt, skipping RESTO lines. A wrong guess beats a 0.00 lie.
  static double _findTotal(List<String> lines) {
    var total = 0.0;
    var found = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final key = _keywordForm(line);
      if (!_totalKeyword.hasMatch(key) || _subtotal.hasMatch(key)) continue;
      found = true;
      final amounts = _amount
          .allMatches(line)
          .map((m) => _parseItalianAmount(m.group(1)!))
          .toList();
      if (amounts.isNotEmpty) {
        total = amounts.last;
      } else if (i + 1 < lines.length) {
        final next = _amount.firstMatch(lines[i + 1]);
        if (next != null) total = _parseItalianAmount(next.group(1)!);
      }
    }
    if (!found) {
      for (var i = lines.length - 1; i >= 0; i--) {
        if (_resto.hasMatch(lines[i].toUpperCase())) continue;
        final amounts = _amount
            .allMatches(lines[i])
            .map((m) => _parseItalianAmount(m.group(1)!))
            .toList();
        if (amounts.isNotEmpty) return amounts.last;
      }
    }
    return total;
  }

  static double _parseItalianAmount(String raw) {
    // "1.234,56" -> 1234.56 ; "10.60" -> 10.60 ; "10,60" -> 10.60
    if (raw.contains(',')) {
      return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.')) ??
          0.0;
    }
    return double.tryParse(raw) ?? 0.0;
  }
}
