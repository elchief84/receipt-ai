/// Transaction extraction from Italian OCR text (regex, no ML).
library;

class SegmentedItem {
  SegmentedItem(this.description, this.price);
  final String description;
  final double? price;
}

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
  static final _totalKeyword = RegExp(
    r'\b(TOTALE|TOTAL|IMPORTO)\b',
    caseSensitive: false,
  );
  static final _subtotal = RegExp(r'SUB\s*TOT', caseSensitive: false);
  static final _resto =
      RegExp(r'\b(RESTO|RESTA|CAMBIO|CHANGE)\b', caseSensitive: false);
  // Trailing (?!\d): dotted phone numbers ("0564.620438") are not amounts.
  static final _amount = RegExp(r'(\d[\d.]*(?:[,.]\d{2}))(?!\d)');

  /// Meta/header lines: never product descriptions (normalized contains).
  static const _metaWords = {
    'riepilogo',
    'ordine',
    'invia',
    'venduto',
    'consegnato',
    'reso',
    'metodo',
    'pagamento',
    'mastercard',
    'torna',
    'aiuto',
    'subtotale',
    'totale',
    'spedizione',
    'iva',
    'condizioni',
    'privacy',
    'stampa',
    'italia',
    'grazie',
    'arrivederci',
    'cassa',
    'scontr',
    'resto',
    'contanti',
    'contante',
    'carta',
    'euro',
    'telefono',
    'cliente',
    'rt', // matricola line, never a product
  };

  static bool _isMeta(String line) {
    // Token-based, never substring: "protettiva" must not match "iva".
    final tokens = line
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();
    return _metaWords.any(tokens.contains);
  }

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
  /// SUBTOTALE lines are ignored; a bare TOTALE scans the next lines.
  /// Fallback with no usable keyword amount (OCR ate it): last amount of
  /// the receipt, skipping RESTO lines. A wrong guess beats a 0.00 lie.
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
      } else {
        // Window of exactly 1: the classic "TOTALE\n13,60" layout only.
        // Wider windows grab footer figures past the total (Amazon case:
        // bare "Totale:", legalese, then subtotal before the grand total).
        // Anything else falls through to the last-amount fallback below.
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
      final match = _amount.firstMatch(lines[i]);
      if (match != null) return _parseItalianAmount(match.group(1)!);
    }
    return null;
  }

  static double? _lastAmountSkippingResto(List<String> lines) {
    for (var i = lines.length - 1; i >= 0; i--) {
      if (_resto.hasMatch(lines[i].toUpperCase())) continue;
      final amounts = _amount
          .allMatches(lines[i])
          .map((m) => _parseItalianAmount(m.group(1)!))
          .toList();
      if (amounts.isNotEmpty) return amounts.last;
    }
    return null;
  }

  /// Product descriptions: one per price line. Same-line remainder wins
  /// (fiscal receipts) unless it is only payment words; otherwise the
  /// nearest usable line above (order summaries). Section boundaries
  /// (totals, resto, cassa) stop the climb; other meta is skipped over.
  /// Pure amounts with no description above are skipped (repeated totals).
  static const _stopDescTokens = {
    'totale',
    'total',
    'subtotale',
    'importo',
    'resto',
    'resta',
    'cambio',
    'change',
    'contanti',
    'contante',
    'euro',
    'iva',
    'cui',
    'di',
  };

  /// Section boundary: totals, change, cashier — never climb past these.
  static bool _isBoundary(String line) {
    final norm = ' ${line.toLowerCase()} ';
    return [
      'totale',
      'totalo', // OCR fragment of TOTALE
      'subtotale',
      'resto',
      'contanti',
      'contante',
      'cassa',
      'scontr',
    ].any(norm.contains);
  }

  /// A segmented product line: description plus the price found on the
  /// same line or on the price line below it. Null price for body-block
  /// items (totals-only receipts like Fenza).
  static List<SegmentedItem> segmentItems(List<String> lines) {
    final items = <SegmentedItem>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Asterisk-led fiscal notes ("* Inp. De traibile 13.60") are never
      // products, even when they carry an amount.
      if (line.trimLeft().startsWith('*')) continue;
      final match = _amount.firstMatch(line);
      if (match == null) continue;
      final price = _parseItalianAmount(match.group(1)!);
      final remainder = line.replaceFirst(match.group(0)!, '').trim();
      // Total lines never become items, whatever the remainder.
      final keyForm = _keywordForm(line);
      if (_totalKeyword.hasMatch(keyForm) || _subtotal.hasMatch(keyForm)) {
        continue;
      }
      // Same-line description must carry a real word (>= 2 chars, not
      // payment-only): "41 s8" or "EURO" alone do not qualify.
      final tokens = _letterTokens(remainder);
      if (tokens.any((t) => t.length >= 2) &&
          tokens.any((t) => !_stopDescTokens.contains(t))) {
        items.add(SegmentedItem(remainder, price));
        continue;
      }
      final above = _nearestDescription(lines, i - 1);
      if (above != null) items.add(SegmentedItem(above, price));
    }
    // No price-anchored item: fall back to the receipt body block
    // (RT layout standard: description header .. IVA/totals trailer).
    if (items.isEmpty) items.addAll(_bodyItems(lines));
    return items;
  }

  /// Start markers of the product body in RT receipts.
  static bool _isBodyStart(String line) {
    return _letterTokens(line).any(
      (t) =>
          t.startsWith('descriz') ||
          t == 'reparto' ||
          t.startsWith('articol') ||
          t == 'prodotto' ||
          t == 'merce',
    );
  }

  /// End markers of the product body: IVA summary, totals, payments.
  /// Prefix-based so mangled OCR ("TTALE CONPLESSIVO") still ends the body.
  static bool _isBodyEnd(String line) {
    final tokens = _letterTokens(line).toSet();
    return tokens.any(
      (t) =>
          t.startsWith('tot') ||
          t.startsWith('tta') ||
          t == 'iva' ||
          t.startsWith('pagamento') ||
          t.startsWith('importo') ||
          t.startsWith('subtotale'),
    );
  }

  /// Joined body lines as a single item: when prices print only in the
  /// totals block, the body still names the purchase (pharmacy case).
  /// Capped: a body is a description, not an essay.
  static List<SegmentedItem> _bodyItems(List<String> lines) {
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      if (_isBodyStart(lines[i])) {
        start = i + 1;
        break;
      }
    }
    if (start < 0) return const [];
    final body = <String>[];
    for (var i = start; i < lines.length; i++) {
      final line = lines[i].trim();
      if (_isBodyEnd(line)) break;
      if (line.startsWith('*')) continue;
      if (_letterTokens(line).any((t) => t.length >= 3) &&
          !_isMeta(line)) {
        body.add(line);
      }
    }
    final joined = body.join(' ');
    if (joined.isEmpty || joined.length > 200) return const [];
    return [SegmentedItem(joined, null)];
  }

  static List<String> _letterTokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .split(' ')
        .where((t) => t.isNotEmpty && int.tryParse(t) == null)
        .toList();
  }

  static String? _nearestDescription(List<String> lines, int from) {
    var steps = 0;
    for (var i = from; i >= 0 && steps < 6; i--, steps++) {
      final line = lines[i];
      if (_amount.hasMatch(line) || _isBoundary(line)) return null;
      // A description needs at least two real words: labels ("Prezzo"),
      // codes ("RT 45...") and fragments ("ale:") never qualify.
      final words = _letterTokens(line).where((t) => t.length >= 2).toList();
      if (words.length < 2 || _isMeta(line)) continue;
      return line;
    }
    return null;
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
