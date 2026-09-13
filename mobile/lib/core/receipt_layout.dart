/// Structural receipt parser: visual rows -> typed rows -> body -> items.
/// Single algorithm for all RT layouts (inline, description-only,
/// two-column, quantity/weight, pre-RT). Replaces the retired pile of
/// single-purpose heuristics (pairColumns/mergeFragments/attachAdjacent).
///
/// Reliability is measurable, not hoped for:
/// - sumOk: priced items sum to the receipt total (ground truth)
/// - itemCount: NUMERO DI ARTICOLI cross-check when printed
library;

import 'dart:ui' show Rect;

import 'receipt_text.dart' as t;

/// One visual row: OCR lines sharing a horizontal band, left to right.
class LayoutRow {
  LayoutRow(this.indices, this.text, this.box);
  final List<int> indices;
  final String text;
  final Rect? box;
}

enum RowKind {
  bodyStart,
  trailer,
  priced,
  bare,
  desc,
  fragment,
  adjustment,
  noise,
}

/// A segmented product: description plus optional price.
class SegmentedItem {
  SegmentedItem(this.description, this.price);
  final String description;
  final double? price;
}

class ReceiptLayout {
  ReceiptLayout({
    required this.items,
    required this.sumOk,
    required this.declaredCount,
  });

  final List<SegmentedItem> items;

  /// True = prices sum to total (verified). False = mismatch (show the
  /// "da verificare" badge). Null = unverifiable (no priced items/total).
  final bool? sumOk;

  /// From "NUMERO DI ARTICOLI: N", null when absent.
  final int? declaredCount;
}

class ReceiptLayoutParser {
  /// Minimum y-overlap (over smaller height) to share a visual row.
  static const rowOverlap = 0.3;

  static ReceiptLayout parse(
    List<String> lines,
    List<Rect?>? boxes,
    double total,
  ) {
    final aligned = boxes != null && boxes.length == lines.length;
    final rows = _buildRows(lines, aligned ? boxes : null);
    final kinds = rows.map(_typeRow).toList();

    // Body: last bodyStart .. first trailer (exclusive). Without a
    // marker, skip the merchant line plus header rows (legal forms,
    // address, phone, P.IVA) — the merchant block never holds items.
    var start = 0;
    var marked = false;
    for (var i = 0; i < rows.length; i++) {
      if (kinds[i] != RowKind.bodyStart) continue;
      if (_isTrailerLike(rows[i].text)) continue;
      // "NUMERO DI ARTICOLI: 15" carries an articol-token but lives in
      // the trailer: never a body header.
      if (_hasToken(rows[i].text, 'numero')) continue;
      start = i + 1;
      marked = true;
    }
    if (!marked) {
      start = 0;
      for (var i = 0; i < rows.length; i++) {
        if (i == 0 || _isHeaderRow(rows[i].text)) {
          start = i + 1;
          continue;
        }
        break;
      }
    }
    var end = rows.length;
    for (var i = start; i < rows.length; i++) {
      if (kinds[i] == RowKind.trailer) {
        end = i;
        break;
      }
    }

    final items = _groupItems(rows, kinds, start, end);
    final declared = _declaredCount(lines);
    final repaired = _repair(items, rows, kinds, end, total);
    return ReceiptLayout(
      items: repaired,
      sumOk: _sumCheck(repaired, total),
      declaredCount: declared,
    );
  }

  static final _headerPattern = RegExp(
    r'\b(SNC|SRL|SPA|SAS|S\.A\.S|S\.N\.C|VIA|V\.LE|PIAZZA|TELEFONO|TEL\b|P\.IVA|PARTITA|FAX)\b',
    caseSensitive: false,
  );

  static bool _isHeaderRow(String text) =>
      _headerPattern.hasMatch(text.toUpperCase());

  static bool _hasToken(String text, String token) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .split(' ')
        .contains(token);
  }

  // ---- Phase 1: visual rows -------------------------------------------

  static List<LayoutRow> _buildRows(List<String> lines, List<Rect?>? boxes) {
    if (boxes == null) {
      return [
        for (var i = 0; i < lines.length; i++)
          LayoutRow([i], lines[i], null),
      ];
    }
    final order = List<int>.generate(lines.length, (i) => i)
      ..sort((a, b) {
        final ta = boxes[a]?.top ?? a * 1e6;
        final tb = boxes[b]?.top ?? b * 1e6;
        final dy = ta.compareTo(tb);
        if (dy != 0) return dy;
        final la = boxes[a]?.left ?? 0.0;
        final lb = boxes[b]?.left ?? 0.0;
        final dx = la.compareTo(lb);
        return dx != 0 ? dx : a.compareTo(b);
      });
    final rows = <LayoutRow>[];
    for (final idx in order) {
      final box = boxes[idx];
      var placed = false;
      if (box != null) {
        for (final row in rows) {
          if (row.box == null) continue;
          if (_yOverlapRatio(box, row.box!) >= rowOverlap) {
            row.indices.add(idx);
            placed = true;
            break;
          }
        }
      }
      if (!placed) rows.add(LayoutRow([idx], '', box));
    }
    for (final row in rows) {
      row.indices.sort();
    }
    rows.sort((a, b) => a.indices.first.compareTo(b.indices.first));
    return [
      for (final row in rows)
        LayoutRow(
          row.indices,
          row.indices.map((i) => lines[i]).join(' '),
          row.box,
        ),
    ];
  }

  static double _yOverlapRatio(Rect a, Rect b) {
    final top = a.top > b.top ? a.top : b.top;
    final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
    final overlap = bottom - top;
    if (overlap <= 0) return 0;
    final minHeight = a.height < b.height ? a.height : b.height;
    if (minHeight <= 0) return 0;
    return overlap / minHeight;
  }

  // ---- Phase 2: row typing --------------------------------------------

  static final _sconto = RegExp(r'\bSCONT', caseSensitive: false);
  static final _declaredCountPattern =
      RegExp(r'NUMERO\D*ARTICOLI\D*(\d+)', caseSensitive: false);
  static final _rtMatricola =
      RegExp(r'\bRT\b\D{0,10}\d{6,}', caseSensitive: false);

  static bool _isTrailerLike(String text) {
    final key = t.keywordForm(text);
    if (t.totalKeywordPattern.hasMatch(key) ||
        t.subtotalPattern.hasMatch(key)) {
      return true;
    }
    final tokens = t.letterTokens(text).toSet();
    const trailerTokens = {
      'totale', 'totalo', 'subtotale', 'iva', 'pagamento', 'importo',
      'resto', 'contanti', 'contante', 'cassa', 'scontr', 'metodo',
      'spedizione', 'riepilogo', 'matricola', 'server',
    };
    // NOTE: no 'documento'/'commerciale' here: "DOCUMENTO COMMERCIALE"
    // also labels mid-body sections (Action). MetaFilter catches it as
    // noise instead.
    // Prefix-based so mangled OCR ("TTALE CONPLESSIVO") still ends.
    if (tokens.any(
      (w) =>
          trailerTokens.contains(w) ||
          w.startsWith('tot') ||
          w.startsWith('tta'),
    )) {
      return true;
    }
    if (_rtMatricola.hasMatch(text.toUpperCase())) return true;
    return false;
  }

  static RowKind _typeRow(LayoutRow row) {
    final text = row.text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return RowKind.noise;
    if (trimmed.startsWith('*')) return RowKind.noise;
    if (t.isBodyStart(text) && !_isTrailerLike(text)) {
      return RowKind.bodyStart;
    }
    if (_isTrailerLike(text)) return RowKind.trailer;
    final amounts = t.amountPattern.allMatches(text).toList();
    if (_sconto.hasMatch(text)) return RowKind.adjustment;
    if (amounts.isNotEmpty) {
      final remainder = text.replaceAll(t.amountPattern, '').trim();
      // Single real word suffices ("LATTE 1.49"); payment-only
      // remainders ("DI CUI IVA 1,60") and fragments stay bare.
      final words =
          t.letterTokens(remainder).where((w) => w.length >= 2).toList();
      if (words.isNotEmpty &&
          words.any((w) => !t.priceStopTokens.contains(w))) {
        return RowKind.priced;
      }
      // Bare amount: totals, IVA figures, repeated figures, or a
      // two-column price waiting for its description row.
      return RowKind.bare;
    }
    // Amount-less informative line.
    final words = t.letterTokens(text).where((w) => w.length >= 2).toList();
    if (words.isEmpty) return RowKind.noise;
    if (t.isMetaLine(text)) return RowKind.noise;
    if (words.length < 2 || text.trim().length < 15) {
      return RowKind.fragment;
    }
    return RowKind.desc;
  }

  static int? _declaredCount(List<String> lines) {
    for (final line in lines) {
      final m = _declaredCountPattern.firstMatch(line);
      if (m != null) return int.tryParse(m.group(1)!);
    }
    return null;
  }

  // ---- Phase 3+4: body grouping ---------------------------------------

  static List<SegmentedItem> _groupItems(
    List<LayoutRow> rows,
    List<RowKind> kinds,
    int start,
    int end,
  ) {
    final items = <_RawItem>[];
    final pending = <int>[];

    void flushPending(double price) {
      if (pending.isEmpty) return;
      // A pending run made only of single-word fragments ("ale:",
      // "Prezzo") is label debris, not a product: drop it instead of
      // crowning it an item. Multi-word rows ("XIAOMI POCO") flush.
      bool isTiny(int i) =>
          t.letterTokens(rows[i].text).where((w) => w.length >= 2).length <
          2;
      if (pending.every(isTiny)) {
        pending.clear();
        return;
      }
      items.add(
        _RawItem(
          pending.map((i) => rows[i].text.trim()).join(' '),
          price,
          pending.first,
        ),
      );
      pending.clear();
    }

    double? amountOf(LayoutRow row) {
      final m = t.amountPattern.firstMatch(row.text);
      return m == null ? null : t.parseItalianAmount(m.group(1)!);
    }

    for (var i = start; i < end; i++) {
      final row = rows[i];
      switch (kinds[i]) {
        case RowKind.priced:
          final price = amountOf(row)!;
          final remainder =
              row.text.replaceAll(t.amountPattern, '').trim();
          // Inline "DESC price": own item; orphans before it stay
          // pending for the next bare price (or body end).
          items.add(_RawItem(remainder, price, i));
        case RowKind.bare:
          // Bare price closes every pending description above
          // (two-column rows, "TOTALE\n13,60" splits).
          flushPending(amountOf(row)!);
        case RowKind.desc:
        case RowKind.fragment:
          pending.add(i);
        case RowKind.adjustment:
          final price = amountOf(row);
          if (price == null) break;
          if (items.isNotEmpty) {
            final last = items.removeLast();
            items.add(_RawItem(last.desc, last.price! - price, last.row));
          }
          // Without a preceding item the discount has nothing to
          // attach to: dropped (never a product of its own).
        case RowKind.bodyStart:
        case RowKind.trailer:
        case RowKind.noise:
          break;
      }
    }
    // Leftovers. Priceless bodies: join when tiny (Fenza), separate
    // rows when long (Action). Priced bodies: fragments attach to the
    // nearest priced item (gap ≤ 2, above first); full descs survive
    // only AFTER the first priced item (before it they are header-ish).
    final pricedRows = [
      for (final e in items)
        if (e.price != null) e.row,
    ];
    if (pending.isNotEmpty) {
      if (pricedRows.isEmpty && pending.length <= 2) {
        final joined = pending.map((i) => rows[i].text.trim()).join(' ');
        if (joined.isNotEmpty && joined.length <= 200) {
          items.add(_RawItem(joined, null, pending.first));
        }
      } else if (pricedRows.isEmpty) {
        for (final i in pending) {
          items.add(_RawItem(rows[i].text.trim(), null, i));
        }
      } else {
        final firstPriced = pricedRows.reduce((a, b) => a < b ? a : b);
        for (final i in pending) {
          if (kinds[i] == RowKind.fragment) {
            _attachOne(items, rows, i);
          } else if (i > firstPriced) {
            items.add(_RawItem(rows[i].text.trim(), null, i));
          }
        }
      }
      pending.clear();
    }
    _attachFragments(items);
    return [
      for (final e in items) SegmentedItem(e.desc, e.price),
    ];
  }

  /// Attaches one fragment row to the nearest priced item (gap ≤ 2 rows,
  /// above preferred). Returns true when attached.
  static bool _attachOne(
    List<_RawItem> items,
    List<LayoutRow> rows,
    int rowIdx,
  ) {
    final text = rows[rowIdx].text.trim();
    if (text.length >= 15) return false;
    var best = -1;
    for (var j = 0; j < items.length; j++) {
      if (items[j].price == null) continue;
      final gap = (items[j].row - rowIdx).abs();
      if (gap > 2) continue;
      if (best < 0 ||
          (items[j].row <= rowIdx &&
              (items[best].row > rowIdx ||
                  (items[best].row - rowIdx).abs() > gap))) {
        best = j;
      }
    }
    if (best < 0) return false;
    if (items[best].row <= rowIdx) {
      items[best].desc = '${items[best].desc} $text';
    } else {
      items[best].desc = '$text ${items[best].desc}';
    }
    return true;
  }

  /// Fragment attach: a short fragment row next to a priced item (row
  /// gap ≤ 2, above preferred) is its continuation ("plast ica"), not a
  /// product. Full descs never merge this way — only short fragments.
  static void _attachFragments(List<_RawItem> items) {
    bool isFragment(_RawItem e) =>
        e.price == null && e.desc.trim().length < 15;
    for (var k = 0; k < items.length; k++) {
      if (!isFragment(items[k])) continue;
      var best = -1;
      for (var j = k - 1; j >= 0 && k - j <= 3; j--) {
        if (items[j].price == null) continue;
        if ((items[k].row - items[j].row).abs() > 2) continue;
        best = j;
        break;
      }
      if (best < 0) {
        for (var j = k + 1;
            j < items.length && j - k <= 3;
            j++) {
          if (items[j].price == null) continue;
          if ((items[j].row - items[k].row).abs() > 2) continue;
          best = j;
          break;
        }
      }
      if (best < 0) continue;
      if (best < k) {
        items[best].desc = '${items[best].desc} ${items[k].desc}';
      } else {
        items[best].desc = '${items[k].desc} ${items[best].desc}';
      }
      items.removeAt(k);
      k--;
    }
  }

  // ---- Phase 5: validation + repair ------------------------------------

  static bool? _sumCheck(List<SegmentedItem> items, double total) {
    final priced = items.where((e) => e.price != null).toList();
    if (priced.isEmpty || total <= 0) return null;
    final sum = priced.fold<double>(0, (a, e) => a + e.price!);
    if ((sum - total).abs() <= 0.01 * priced.length + 0.01) return true;
    return false;
  }

  /// Repair: drop priced items whose price also floats bare in the
  /// trailer (repeated totals), then re-check. Single-item attempts.
  static List<SegmentedItem> _repair(
    List<SegmentedItem> items,
    List<LayoutRow> rows,
    List<RowKind> kinds,
    int end,
    double total,
  ) {
    if (_sumCheck(items, total) != false) return items;
    final trailerPrices = <double>{};
    for (var i = end; i < rows.length; i++) {
      for (final m in t.amountPattern.allMatches(rows[i].text)) {
        trailerPrices.add(t.parseItalianAmount(m.group(1)!));
      }
    }
    for (var i = 0; i < items.length; i++) {
      final price = items[i].price;
      if (price == null || !trailerPrices.contains(price)) continue;
      final candidate = [...items]..removeAt(i);
      if (_sumCheck(candidate, total) == true) return candidate;
    }
    return items;
  }
}

class _RawItem {
  _RawItem(this.desc, this.price, this.row);
  String desc;
  double? price;
  final int row;
}
