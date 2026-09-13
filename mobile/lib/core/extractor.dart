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
  static final _total = RegExp(
    r'(?:TOTALE|TOTAL|IMPORTO|TOT)\s*€?\s*(\d[\d.]*(?:[,.]\d{2}))',
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
    }

    var total = 0.0;
    final totalMatch = _total.firstMatch(ocrText);
    if (totalMatch != null) {
      total = _parseItalianAmount(totalMatch.group(1)!);
    }

    return TransactionDraft(
      merchantRaw: merchantRaw,
      date: date,
      total: total,
      currency: 'EUR',
      ocrText: ocrText,
    );
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
