/// Transaction extraction from Italian OCR text (regex, no ML).
library;

import 'dart:ui' show Rect;

class SegmentedItem {
  SegmentedItem(this.description, this.price);
  final String description;
  final double? price;
}

/// Internal item with the source line index, for geometry pairing.
class _Seg {
  _Seg(this.description, this.price, this.src);
  String description;
  double? price;
  final int src;
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
    'documento',
    'commerciale',
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
  /// same line, above it, or on the same visual row (two-column layout,
  /// when boxes are provided). Null price only when no price is found.
  static List<SegmentedItem> segmentItems(
    List<String> lines, [
    List<Rect?>? boxes,
  ]) {
    final boxesForPairing =
        boxes != null && boxes.length == lines.length ? boxes : null;
    // Body-first: when the receipt names its products in a body block
    // (ARTICOLI .. TOTALE), the body IS the item list — trailer prices
    // must not attach header junk ("Auth. code"). Without a body block,
    // fall back to price-anchored lines (inline "LATTE 1.49").
    final body = _bodyBlock(lines);
    final List<_Seg> segs;
    if (body != null) {
      segs = body;
    } else {
      segs = <_Seg>[];
      for (var i = 0; i < lines.length; i++) {
        final found = _priceAnchored(lines, i);
        if (found != null) segs.add(found);
      }
    }
    if (boxesForPairing != null) {
      _pairColumns(segs, lines, boxesForPairing);
      _mergeFragments(segs, boxesForPairing);
    }
    // Leftover priceless few: one product split across lines (Fenza).
    // Pairing runs first so two-column rows keep their prices.
    if (segs.length <= 2 && segs.isNotEmpty && segs.every((e) => e.price == null)) {
      final joined = segs.map((e) => e.description).join(' ');
      if (joined.isNotEmpty && joined.length <= 200) {
        return [SegmentedItem(joined, null)];
      }
    }
    return segs.map((s) => SegmentedItem(s.description, s.price)).toList();
  }

  /// Price-anchored item for line i, or null.
  static _Seg? _priceAnchored(List<String> lines, int i) {
    final line = lines[i];
    // Asterisk-led fiscal notes ("* Inp. De traibile 13.60") are never
    // products, even when they carry an amount.
    if (line.trimLeft().startsWith('*')) return null;
    final match = _amount.firstMatch(line);
    if (match == null) return null;
    final price = _parseItalianAmount(match.group(1)!);
    final remainder = line.replaceFirst(match.group(0)!, '').trim();
    // Total lines never become items, whatever the remainder.
    final keyForm = _keywordForm(line);
    if (_totalKeyword.hasMatch(keyForm) || _subtotal.hasMatch(keyForm)) {
      return null;
    }
    // Same-line description must carry a real word (>= 2 chars, not
    // payment-only): "41 s8" or "EURO" alone do not qualify.
    final tokens = _letterTokens(remainder);
    if (tokens.any((t) => t.length >= 2) &&
        tokens.any((t) => !_stopDescTokens.contains(t))) {
      return _Seg(remainder, price, i);
    }
    final above = _nearestDescription(lines, i - 1);
    if (above >= 0) return _Seg(lines[above], price, above);
    return null;
  }

  /// Two-column pairing: bare amounts join every priceless description
  /// on the same visual row into ONE item (multi-line product names).
  /// Totals and IVA amounts sit below the descriptions, so geometry
  /// excludes them. Threshold 0.3 (not 0.5): a price straddling two
  /// desc rows overlaps each only partially.
  static void _pairColumns(
    List<_Seg> segs,
    List<String> lines,
    List<Rect?> boxes,
  ) {
    for (var i = 0; i < lines.length; i++) {
      final box = boxes[i];
      if (box == null) continue;
      final match = _amount.firstMatch(lines[i]);
      if (match == null) continue;
      // Skip lines that already are (or contain) descriptions or totals:
      // only bare amounts pair across columns.
      final remainder = lines[i].replaceFirst(match.group(0)!, '').trim();
      if (_letterTokens(remainder).any((t) => t.length >= 2)) continue;
      final keyForm = _keywordForm(lines[i]);
      if (_totalKeyword.hasMatch(keyForm) || _subtotal.hasMatch(keyForm)) {
        continue;
      }
      final group = <_Seg>[];
      for (final seg in segs) {
        if (seg.price != null) continue;
        final other = boxes[seg.src];
        if (other == null) continue;
        if (_yOverlap(box, other) >= 0.3) group.add(seg);
      }
      if (group.isEmpty) continue;
      group.sort((a, b) => a.src.compareTo(b.src));
      final first = group.first;
      first.description =
          group.map((s) => s.description).join(' ');
      first.price = _parseItalianAmount(match.group(1)!);
      for (final dup in group.skip(1)) {
        segs.remove(dup);
      }
    }
  }

  /// Fragment merge: a short priceless line hugging the item above is
  /// its continuation ("plast ica" under "disney palla di nat"), not a
  /// new product. Needs boxes (gap measurement); without them the rows
  /// stay split. Cascades: merged blobs absorb further fragments.
  static void _mergeFragments(List<_Seg> segs, List<Rect?> boxes) {
    for (var k = segs.length - 1; k > 0; k--) {
      final cur = segs[k];
      if (cur.price != null) continue;
      if (cur.description.trim().length >= 15) continue;
      final prev = segs[k - 1];
      final curBox = boxes[cur.src];
      final prevBox = boxes[prev.src];
      if (curBox == null || prevBox == null) continue;
      if (curBox.top - prevBox.bottom > 1.5 * prevBox.height) continue;
      prev.description = '${prev.description} ${cur.description}';
      prev.price ??= cur.price;
      segs.removeAt(k);
    }
  }

  static double _yOverlap(Rect a, Rect b) {
    final top = a.top > b.top ? a.top : b.top;
    final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
    final overlap = bottom - top;
    if (overlap <= 0) return 0;
    final minHeight = a.height < b.height ? a.height : b.height;
    if (minHeight <= 0) return 0;
    return overlap / minHeight;
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

  /// Body block: product lines between the description header and the
  /// IVA/totals trailer. Lines carrying their own amount keep their
  /// price; the rest are descriptions. A body of <= 2 priceless lines is
  /// one product split across lines (Fenza) and gets joined.
  /// Returns null when no body header exists (caller uses price lines).
  /// Returns possibly-empty when the header exists: the body is trusted
  /// and trailer junk stays out.
  static List<_Seg>? _bodyBlock(List<String> lines) {
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      // A totals line mentioning articles ("Subtotale articoli:") is a
      // trailer, never a body header.
      if (_isBodyEnd(lines[i]) || _isBoundary(lines[i])) continue;
      if (_isBodyStart(lines[i])) {
        start = i + 1;
        break;
      }
    }
    if (start < 0) return null;
    final items = <_Seg>[];
    for (var i = start; i < lines.length; i++) {
      final line = lines[i].trim();
      if (_isBodyEnd(line)) break;
      if (line.startsWith('*')) continue;
      final match = _amount.firstMatch(line);
      if (match != null) {
        final remainder = line.replaceFirst(match.group(0)!, '').trim();
        final tokens = _letterTokens(remainder);
        if (tokens.any((t) => t.length >= 2) &&
            tokens.any((t) => !_stopDescTokens.contains(t))) {
          items.add(
            _Seg(remainder, _parseItalianAmount(match.group(1)!), i),
          );
        }
        continue;
      }
      if (_isBoundary(line) || _isMeta(line)) continue;
      final tokens = _letterTokens(line);
      if (tokens.any((t) => t.length >= 3) && !_allDigitHeavy(tokens)) {
        items.add(_Seg(line, null, i));
      }
    }
    // Joining of priceless leftovers happens in segmentItems AFTER
    // column pairing, so two-column rows keep their prices (Action)
    // while split single products still join (Fenza).
    // Empty trusted body: fall back to price-anchored lines rather than
    // showing nothing (e.g. trailer-only "NUMERO DI ARTICOLI").
    if (items.isEmpty) return null;
    return items;
  }

  static bool _allDigitHeavy(List<String> tokens) =>
      tokens.isNotEmpty &&
      tokens.every((t) => RegExp(r'\d').hasMatch(t));

  static List<String> _letterTokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .split(' ')
        .where((t) => t.isNotEmpty && int.tryParse(t) == null)
        .toList();
  }

  static int _nearestDescription(List<String> lines, int from) {
    var steps = 0;
    for (var i = from; i >= 0 && steps < 6; i--, steps++) {
      final line = lines[i];
      if (_amount.hasMatch(line) || _isBoundary(line)) return -1;
      // A description needs at least two real words: labels ("Prezzo"),
      // codes ("RT 45...") and fragments ("ale:") never qualify.
      final words = _letterTokens(line).where((t) => t.length >= 2).toList();
      if (words.length < 2 || _isMeta(line)) continue;
      return i;
    }
    return -1;
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
