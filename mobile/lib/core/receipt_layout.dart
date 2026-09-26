/// Structural receipt parser: visual rows -> typed rows -> body -> items.
/// Single algorithm for all RT layouts (inline, description-only,
/// two-column, quantity/weight, pre-RT). Replaces the retired pile of
/// single-purpose heuristics (pairColumns/mergeFragments/attachAdjacent).
///
/// Reliability is measurable, not hoped for:
/// - sumOk: priced items sum to the receipt total (ground truth)
/// - itemCount: NUMERO DI ARTICOLI cross-check when printed
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import 'receipt_text.dart' as t;

/// Full geometry of one OCR line: the axis-aligned box plus the tilt
/// (angle/corners) and confidence ML Kit already provides. [box] alone
/// flattens tilt that the parser needs to de-skew real photos.
class LineGeometry {
  const LineGeometry(
    this.box, {
    this.angle,
    this.corners = const [],
    this.confidence,
  });
  final Rect box;
  final double? angle;
  final List<Offset> corners;
  final double? confidence;
}

/// One visual row: OCR lines sharing a horizontal band, left to right.
class LayoutRow {
  LayoutRow(
    this.indices,
    this.text,
    this.box, {
    this.confidence,
    this.corners = const [],
  });
  final List<int> indices;
  final String text;
  final Rect? box;

  /// Lowest per-line OCR confidence in the row, null when unknown. Low
  /// values mean the OCR is unsure: callers flag the row, never trust it
  /// blindly.
  final double? confidence;

  /// Corners of the left-most member line, when available. Used for the
  /// right-aligned price column (true right edge, not the padded box).
  final List<Offset> corners;
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

/// Minimum per-line OCR confidence to treat a parsed item as certain.
/// Configurable: items below it are flagged, never silently trusted.
const minLineConfidence = 0.6;

/// A segmented product: description plus optional price.
class SegmentedItem {
  SegmentedItem(this.description, this.price, {this.confidence});
  final String description;
  final double? price;

  /// Lowest OCR confidence among the lines that formed this item, null
  /// when unknown. Drives [isLowConfidence].
  final double? confidence;

  /// The OCR was unsure about this item: surface it as "da verificare".
  bool get isLowConfidence =>
      confidence != null && confidence! < minLineConfidence;
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

  /// Items whose OCR confidence is below [minLineConfidence].
  int get lowConfidenceCount =>
      items.where((e) => e.isLowConfidence).length;
}

class ReceiptLayoutParser {
  /// Minimum y-overlap (over smaller height) to share a visual row.
  static const rowOverlap = 0.3;

  /// Back-compat entry point for callers that only have axis-aligned
  /// boxes (samples, tests). Wraps each box as geometry with no tilt.
  static ReceiptLayout parse(
    List<String> lines,
    List<Rect?>? boxes,
    double total,
  ) =>
      parseLines(
        lines,
        boxes == null
            ? null
            : [for (final b in boxes) b == null ? null : LineGeometry(b)],
        total,
      );

  static ReceiptLayout parseLines(
    List<String> lines,
    List<LineGeometry?>? geoms,
    double total,
  ) {
    final aligned = geoms != null && geoms.length == lines.length;
    final rows = _buildRows(lines, aligned ? geoms : null);
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

    final grouped = _groupItems(rows, kinds, start, end);
    final raw = grouped.items;
    // NOTE: declared count is NOT a merge guard — OCR routinely drops
    // product lines, so raw rows != declared items even when parsed
    // perfectly.
    _pairPositional(
        raw, rows, kinds, start, end, grouped.consumedBare, aligned);
    _mergeContinuations(raw, rows);
    _attachOrphans(raw, rows, total, _declaredCount(lines));
    final items = [
      for (final e in raw)
        SegmentedItem(
          _stripLeadingCode(e.desc),
          e.price,
          confidence: e.confidence,
        ),
    ];
    final repaired = _repair(items, rows, kinds, end, total);
    final declared = _declaredCount(lines);
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

  /// Builds visual rows in canonical reading order (top→bottom, left→
  /// right), tilt-corrected. Two defects this replaces:
  /// - rows were re-sorted by ML Kit EMISSION index, scrambling the
  ///   physical order ("righe mischiate");
  /// - overlap clustering tolerated ~2° of tilt only.
  static List<LayoutRow> _buildRows(
    List<String> lines,
    List<LineGeometry?>? geoms,
  ) {
    if (geoms == null) {
      return [
        for (var i = 0; i < lines.length; i++)
          LayoutRow([i], lines[i], null),
      ];
    }
    final geomOf = <int, LineGeometry>{};
    for (var i = 0; i < lines.length; i++) {
      final g = geoms[i];
      if (g != null && g.box.height > 0 && g.box.width > 0) geomOf[i] = g;
    }
    if (geomOf.isEmpty) {
      return [
        for (var i = 0; i < lines.length; i++)
          LayoutRow([i], lines[i], null),
      ];
    }
    final boxOf = <int, Rect>{for (final e in geomOf.entries) e.key: e.value.box};
    final idxs = geomOf.keys.toList()..sort();
    final heights = idxs.map((i) => boxOf[i]!.height).toList()..sort();
    final hMed = heights[heights.length ~/ 2];
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    for (final b in boxOf.values) {
      if (b.left < minX) minX = b.left;
      if (b.right > maxX) maxX = b.right;
    }
    final pageW = maxX - minX > 1 ? maxX - minX : 1.0;

    // Tilt estimate, best evidence first:
    // 1. per-line tilt from ML Kit corners/angle (true geometry, robust
    //    on real photos with perspective residue);
    // 2. fallback: cross-column, vertically-close PAIRS of boxes carry
    //    the angle (same physical row, different x). Left-column-only
    //    pairs would conflate content drift with tilt. Median for
    //    robustness.
    final tiltSamples = <double>[];
    for (final i in idxs) {
      final s = _slopeFromGeometry(geomOf[i]!);
      if (s != null && s.isFinite) tiltSamples.add(s);
    }
    double slope;
    if (tiltSamples.isNotEmpty) {
      tiltSamples.sort();
      slope = tiltSamples[tiltSamples.length ~/ 2];
    } else {
      final samples = <double>[];
      for (var a = 0; a < idxs.length; a++) {
        for (var b = a + 1; b < idxs.length; b++) {
          final ra = boxOf[idxs[a]]!;
          final rb = boxOf[idxs[b]]!;
          final gap =
              rb.left >= ra.left ? rb.left - ra.right : ra.left - rb.right;
          if (gap < 0 || gap > pageW * 0.35) continue;
          final cya = (ra.top + ra.bottom) / 2;
          final cyb = (rb.top + rb.bottom) / 2;
          if ((cya - cyb).abs() > 0.8 * hMed) continue;
          final dxa = (ra.left + ra.right) / 2;
          final dxb = (rb.left + rb.right) / 2;
          final dx = dxb - dxa;
          if (dx.abs() < 1) continue;
          samples.add((cyb - cya) / dx);
        }
      }
      samples.sort();
      slope = samples.length >= 3 ? samples[samples.length ~/ 2] : 0.0;
    }
    if (slope.abs() > 0.15) slope = 0.0; // >8.5°: garbage, trust nothing

    double deskew(int i) {
      final b = boxOf[i]!;
      return (b.top + b.bottom) / 2 - slope * (b.left + b.right) / 2;
    }

    final ordered = idxs.toList()
      ..sort((a, b) {
        final d = deskew(a).compareTo(deskew(b));
        if (d != 0) return d;
        return boxOf[a]!.left.compareTo(boxOf[b]!.left);
      });

    // Two-phase clustering on de-skewed bands.
    // Phase A: TEXT rows cluster among themselves. Each row keeps its
    // CORE band fixed at creation (first member) — the band NEVER grows,
    // so chaining is impossible by construction (a growing union glued
    // a 216px header into one row). Threshold 0.5: adjacent receipt
    // lines genuinely overlap less than half their height.
    // Phase B: AMOUNT lines never seed rows. Each attaches to the text
    // row with maximum overlap (≥ 0.3 — short right-column boxes
    // legitimately overlap partially), else becomes its own bare row.
    // A price between two descriptions joins the one it really overlaps.
    final building = <_RowBuild>[];
    final pendingAmounts = <int>[];
    for (final idx in ordered) {
      final text = lines[idx];
      // Bare amounts (no description of their own) attach in Phase B.
      // Inline "DESC price" rows stay text rows: they seed the skeleton.
      if (_isBareAmountLine(text)) {
        pendingAmounts.add(idx);
        continue;
      }
      final b = boxOf[idx]!;
      final cx = (b.left + b.right) / 2;
      final top = b.top - slope * cx;
      final bottom = b.bottom - slope * cx;
      var best = -1;
      var bestOverlap = 0.5;
      for (var r = 0; r < building.length; r++) {
        final row = building[r];
        final overlap =
            (bottom < row.bottom ? bottom : row.bottom) -
            (top > row.top ? top : row.top);
        final ownH = bottom - top;
        final rowH = row.bottom - row.top;
        final minH = ownH < rowH ? ownH : rowH;
        if (minH <= 0) continue;
        final ratio = overlap / minH;
        if (ratio > bestOverlap) {
          bestOverlap = ratio;
          best = r;
        }
      }
      if (best >= 0) {
        building[best].indices.add(idx);
      } else {
        building.add(_RowBuild(top, bottom, idx));
      }
    }
    for (final idx in pendingAmounts) {
      final b = boxOf[idx]!;
      final cx = (b.left + b.right) / 2;
      final top = b.top - slope * cx;
      final bottom = b.bottom - slope * cx;
      var best = -1;
      var bestOverlap = rowOverlap;
      for (var r = 0; r < building.length; r++) {
        final row = building[r];
        final overlap =
            (bottom < row.bottom ? bottom : row.bottom) -
            (top > row.top ? top : row.top);
        final ownH = bottom - top;
        final rowH = row.bottom - row.top;
        final minH = ownH < rowH ? ownH : rowH;
        if (minH <= 0) continue;
        final ratio = overlap / minH;
        if (ratio > bestOverlap) {
          bestOverlap = ratio;
          best = r;
        }
      }
      if (best >= 0) {
        building[best].indices.add(idx);
      } else {
        building.add(_RowBuild(top, bottom, idx));
      }
    }
    // Null-box lines (rare on ML Kit): appended in emission order.
    for (var i = 0; i < lines.length; i++) {
      if (boxOf.containsKey(i)) continue;
      building.add(_RowBuild(1e9 + i, 1, i));
    }
    return [
      for (final r in building)
        LayoutRow(
          r.indices..sort((a, b) => boxOf[a]!.left.compareTo(boxOf[b]!.left)),
          r.indices.map((i) => lines[i]).join(' '),
          boxOf[r.indices.first],
          confidence: _minConfidence(r.indices, geomOf),
          corners: geomOf[r.indices.first]?.corners ?? const [],
        ),
    ];
  }

  /// Right edge of a row's left-most box: from corners when present (true
  /// rotated right edge), else the axis-aligned box.
  static double _rightEdge(LayoutRow row) {
    if (row.corners.isNotEmpty) {
      var maxX = double.negativeInfinity;
      for (final c in row.corners) {
        if (c.dx > maxX) maxX = c.dx;
      }
      if (maxX.isFinite) return maxX;
    }
    return row.box?.right ?? double.nan;
  }

  /// Detects a right-aligned price column among candidate bare rows: the
  /// median right edge, kept only when at least 3 rows agree within a
  /// tolerance of half their text height (right-aligned amounts line up;
  /// centered/left numbers do not). Null when there is no such column.
  static ({double right, int count})? detectPriceColumn(
    List<LayoutRow> rows,
    List<int> candidates,
  ) {
    final samples = <({double right, double h})>[];
    for (final i in candidates) {
      final r = rows[i];
      final right = _rightEdge(r);
      if (right.isNaN || !right.isFinite) continue;
      final h = r.box?.height ?? 0;
      samples.add((right: right, h: h > 0 ? h : 0));
    }
    if (samples.length < 3) return null;
    final rights = [for (final s in samples) s.right]..sort();
    final med = rights[rights.length ~/ 2];
    final hs = [for (final s in samples) s.h]..sort();
    final hMed = hs[hs.length ~/ 2] > 0 ? hs[hs.length ~/ 2] : 1.0;
    final tol = 0.5 * hMed;
    final aligned =
        samples.where((s) => (s.right - med).abs() <= tol).length;
    if (aligned * 3 < samples.length * 2) return null; // < ~66%
    return (right: med, count: aligned);
  }

  /// Tilt of one line as a slope (dy/dx), from ML Kit corners when
  /// present, else its rotation angle. Null when neither is available.
  static double? _slopeFromGeometry(LineGeometry g) {
    final c = g.corners;
    if (c.length >= 2) {
      final dx = c[1].dx - c[0].dx;
      if (dx.abs() > 1) return (c[1].dy - c[0].dy) / dx;
    }
    final a = g.angle;
    if (a != null) {
      final slope = math.tan(a * math.pi / 180.0);
      if (slope.isFinite) return slope;
    }
    return null;
  }

  /// Lowest known per-line OCR confidence in a row (null when all
  /// unknown). Conservative: the row is only as trustworthy as its
  /// weakest line.
  static double? _minConfidence(
    List<int> indices,
    Map<int, LineGeometry> geomOf,
  ) {
    double? min;
    for (final i in indices) {
      final c = geomOf[i]?.confidence;
      if (c == null) continue;
      if (min == null || c < min) min = c;
    }
    return min;
  }

  // ---- Phase 2: row typing --------------------------------------------

  /// A line is a bare amount when it carries a price but no description
  /// of its own ("3,99" yes; "LATTE 1.49" no). Mirrors _typeRow's
  /// priced/bare split exactly.
  static bool _isBareAmountLine(String text) {
    if (!t.amountPattern.hasMatch(text)) return false;
    final remainder = text.replaceAll(t.amountPattern, '').trim();
    final words =
        t.letterTokens(remainder).where((w) => w.length >= 2).toList();
    return !(words.isNotEmpty &&
        words.any((w) => !t.priceStopTokens.contains(w)));
  }

  static final _sconto = RegExp(r'\bSCONT', caseSensitive: false);
  static final _declaredCountPattern =
      RegExp(r'NUMERO\D*ARTICOLI\D*(\d+)', caseSensitive: false);
  static final _rtMatricola =
      RegExp(r'\bRT\b\D{0,10}\d{6,}', caseSensitive: false);

  /// Introspection for the debug overlay (issue #9): the typed visual
  /// rows the parser builds, geometry included. Not a test-only seam —
  /// the dev overlay screen consumes it.
  static List<({LayoutRow row, RowKind kind})> typedRows(
    List<String> lines,
    List<LineGeometry?>? geoms,
  ) {
    final aligned = geoms != null && geoms.length == lines.length;
    final rows = _buildRows(lines, aligned ? geoms : null);
    return [for (final r in rows) (row: r, kind: _typeRow(r))];
  }

  /// Test seam: the visual rows the parser builds, geometry included.
  @visibleForTesting
  static List<LayoutRow> debugBuildRows(
    List<String> lines,
    List<LineGeometry?>? geoms,
  ) {
    final aligned = geoms != null && geoms.length == lines.length;
    return _buildRows(lines, aligned ? geoms : null);
  }

  /// Test seam: typed visual rows for a given input (what the parser
  /// actually sees, geometry included).
  @visibleForTesting
  static List<(String text, RowKind kind)> debugRows(
    List<String> lines,
    List<Rect?>? boxes,
  ) {
    final aligned = boxes != null && boxes.length == lines.length;
    final rows = _buildRows(
      lines,
      aligned
          ? [for (final b in boxes) b == null ? null : LineGeometry(b)]
          : null,
    );
    final kinds = rows.map(_typeRow).toList();
    return [
      for (var i = 0; i < rows.length; i++) (rows[i].text, kinds[i]),
    ];
  }

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

  /// Article codes ("3207757 disney...") are inventory references, not
  /// part of the product name: strip a leading pure-digit run.
  /// "21x20x26cm ..." and "1ab31 ..." survive (no whitespace right
  /// after the digits).
  static final _leadingCode = RegExp(r'^\d{1,8}\s+');
  static String _stripLeadingCode(String desc) =>
      desc.replaceFirst(_leadingCode, '');

  // ---- Phase 3+4: body grouping ---------------------------------------

  static ({List<_RawItem> items, Set<int> consumedBare}) _groupItems(
    List<LayoutRow> rows,
    List<RowKind> kinds,
    int start,
    int end,
  ) {
    final items = <_RawItem>[];
    final pending = <int>[];
    final consumedBare = <int>{};

    // Lowest OCR confidence among the rows that formed one item (null
    // when all unknown): the item is only as certain as its weakest line.
    double? minConf(Iterable<int> idxs) {
      double? m;
      for (final i in idxs) {
        final c = rows[i].confidence;
        if (c == null) continue;
        if (m == null || c < m) m = c;
      }
      return m;
    }

    void flushPending(double price, int rowIdx) {
      consumedBare.add(rowIdx);
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
          confidence: minConf(pending),
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
          items.add(_RawItem(remainder, price, i, confidence: row.confidence));
        case RowKind.bare:
          // Bare price closes every pending description above
          // (two-column rows, "TOTALE\n13,60" splits).
          flushPending(amountOf(row)!, i);
        case RowKind.desc:
        case RowKind.fragment:
          pending.add(i);
        case RowKind.adjustment:
          final price = amountOf(row);
          if (price == null) break;
          if (items.isNotEmpty) {
            final last = items.removeLast();
            items.add(
              _RawItem(
                last.desc,
                last.price! - price,
                last.row,
                confidence: last.confidence,
              ),
            );
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
          items.add(
            _RawItem(
              joined,
              null,
              pending.first,
              confidence: minConf(pending),
            ),
          );
        }
      } else if (pricedRows.isEmpty) {
        for (final i in pending) {
          items.add(
            _RawItem(
              rows[i].text.trim(),
              null,
              i,
              confidence: rows[i].confidence,
            ),
          );
        }
      } else {
        final firstPriced = pricedRows.reduce((a, b) => a < b ? a : b);
        for (final i in pending) {
          if (kinds[i] == RowKind.fragment) {
            _attachOne(items, rows, i);
          } else if (i > firstPriced) {
            items.add(
              _RawItem(
                rows[i].text.trim(),
                null,
                i,
                confidence: rows[i].confidence,
              ),
            );
          }
        }
      }
      pending.clear();
    }
    _attachFragments(items, rows);
    return (items: items, consumedBare: consumedBare);
  }

  /// Post-zip continuation merge: a continuation row joins the nearest
  /// item (above preferred, band gap ≤ ~1 line). Sum-safe by
  /// construction: a merge fires only when at most one side carries a
  /// price, and the survivor keeps it — the total can never move.
  /// Continuation = short fragment ("plast ica"), a measurement
  /// ("30x45cm") or a dimensions line ("21x20x26cm div, co"): none of
  /// these is ever a standalone product. Full descriptions (aquarel,
  /// Scherino) stay separate — genuinely ambiguous, user verifies.
  static void _mergeContinuations(
    List<_RawItem> items,
    List<LayoutRow> rows,
  ) {
    var changed = true;
    while (changed) {
      changed = false;
      for (var k = 0; k < items.length; k++) {
        final cur = items[k];
        if (!_isContinuation(cur.desc) && !_hasDimsToken(cur.desc)) {
          continue;
        }
        var best = -1;
        var bestGap = double.infinity;
        for (var j = 0; j < items.length; j++) {
          if (j == k) continue;
          final other = items[j];
          if (cur.price != null && other.price != null) continue;
          final gap = _rowGapY(rows, other.row, cur.row);
          if (gap > 1.0) continue;
          final above = other.row <= cur.row;
          if (best < 0 ||
              gap < bestGap - 1e-9 ||
              ((gap - bestGap).abs() < 1e-9 &&
                  above &&
                  items[best].row > cur.row)) {
            best = j;
            bestGap = gap;
          }
        }
        if (best < 0) continue;
        final target = items[best];
        if (target.row <= cur.row) {
          target.desc = '${target.desc} ${cur.desc}';
        } else {
          target.desc = '${cur.desc} ${target.desc}';
        }
        target.price ??= cur.price;
        target.confidence = _minConf(target.confidence, cur.confidence);
        items.removeAt(k);
        changed = true;
        break;
      }
    }
  }

  static final _dimsToken =
      RegExp(r'\d+\s*[x×]\s*\d+', caseSensitive: false);
  static bool _hasDimsToken(String desc) => _dimsToken.hasMatch(desc);

  /// Orphan attach: when the prices add up exactly AND every declared
  /// product already has its price, leftover priceless descriptions
  /// cannot be products (all prices accounted for) — they are
  /// continuations of the item directly above (band gap ≤ ~1 line).
  /// Fires ONLY in the exact-accounted case; otherwise leftovers stay
  /// visible and honest. Verified on Action: aquarel→1ibro,
  /// Scherino→1ab31, 15 items = 15 declared.
  static void _attachOrphans(
    List<_RawItem> items,
    List<LayoutRow> rows,
    double total,
    int? declared,
  ) {
    if (declared == null || total <= 0) return;
    final priced = items.where((e) => e.price != null).toList();
    if (priced.length != declared) return;
    final sum = priced.fold<double>(0, (a, e) => a + e.price!);
    if ((sum - total).abs() > 0.01 * priced.length + 0.01) return;
    for (var k = 0; k < items.length; k++) {
      final cur = items[k];
      if (cur.price != null) continue;
      if (cur.desc.trim().isEmpty) continue;
      // Nearest item PHYSICALLY above (row numbers, not list positions:
      // inline-priced items enter during the loop, pending descs at the
      // end, so list order ≠ row order). Continuations follow their
      // product — never the other way round.
      var best = -1;
      var bestGap = double.infinity;
      for (var j = 0; j < items.length; j++) {
        if (j == k) continue;
        if (items[j].row >= cur.row) continue;
        final gap = _rowGapY(rows, items[j].row, cur.row);
        if (gap > 1.0) continue;
        if (gap < bestGap) {
          best = j;
          bestGap = gap;
        }
      }
      if (best < 0) continue;
      items[best].desc = '${items[best].desc} ${cur.desc}';
      items[best].confidence = _minConf(items[best].confidence, cur.confidence);
      items.removeAt(k);
      k--;
    }
  }

  /// Lowest known of two OCR confidences (null means unknown, not zero).
  static double? _minConf(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  static final _measurePattern = RegExp(
    r'^[\dx×,.\s/\-]*\s*(cm|mm|kg|g|ml|l|cl|pz|gr|m|lt)\.?$',
    caseSensitive: false,
  );

  static bool _isContinuation(String desc) {
    final text = desc.trim();
    if (text.length < 15) return true;
    return _measurePattern.hasMatch(text);
  }

  /// Positional zip for two-column layouts: bare amounts pair in order
  /// with priceless descriptions.
  ///
  /// Two paths, chosen by evidence quality:
  /// - WITH geometry: row-based. Only bare rows physically ABOVE the
  ///   totals row qualify — product prices sit next to their products,
  ///   never below TOTALE (this structurally excludes the IVA trio,
  ///   repeated totals and card blocks). Rows already consumed by
  ///   grouping are skipped: no double count. A SPECIFICA backstop
  ///   covers receipts whose trailer wasn't detected.
  /// - WITHOUT geometry (samples/tests): legacy EUR-marker scan over
  ///   the emission-order lines. Weaker, but it's all the evidence
  ///   there is.
  static void _pairPositional(
    List<_RawItem> items,
    List<LayoutRow> rows,
    List<RowKind> kinds,
    int start,
    int end,
    Set<int> consumedBare,
    bool hasGeometry,
  ) {
    final amounts = <double>[];
    if (hasGeometry) {
      final boundY =
          end < rows.length ? _centerY(rows[end]) : double.infinity;
      var specificaIdx = rows.length;
      for (var i = end; i < rows.length; i++) {
        if (_hasToken(rows[i].text, 'specifica')) {
          specificaIdx = i;
          break;
        }
      }
      final candidates = <int>[];
      for (var i = start; i < end; i++) {
        if (kinds[i] != RowKind.bare) continue;
        if (consumedBare.contains(i)) continue;
        if (_centerY(rows[i]) >= boundY) continue;
        if (i >= specificaIdx) continue;
        if (!t.amountPattern.hasMatch(rows[i].text)) continue;
        candidates.add(i);
      }
      // Right-aligned price column, when it exists, anchors the pairing:
      // only amounts on the column pair, in spatial (top→bottom) order.
      // Stray numbers off the column (fragment of a description, a code)
      // are excluded instead of shifting every pairing below them.
      final column = detectPriceColumn(rows, candidates);
      var ordered = candidates;
      if (column != null) {
        final hMed = [
          for (final i in candidates)
            (rows[i].box?.height ?? 0) > 0 ? rows[i].box!.height : 1.0,
        ]..sort();
        final tol = 0.5 * hMed[hMed.length ~/ 2];
        ordered = [
          for (final i in candidates)
            if ((_rightEdge(rows[i]) - column.right).abs() <= tol) i,
        ];
      }
      ordered = ordered.toList()
        ..sort((a, b) => _centerY(rows[a]).compareTo(_centerY(rows[b])));
      for (final i in ordered) {
        final m = t.amountPattern.firstMatch(rows[i].text);
        if (m == null) continue;
        amounts.add(t.parseItalianAmount(m.group(1)!));
      }
    } else {
      final lines = [for (final r in rows) r.text];
      var eur = -1;
      for (var i = end; i < lines.length; i++) {
        if (_isEurMarker(lines[i])) eur = i;
      }
      if (eur < 0) return;
      for (var i = eur + 1; i < lines.length; i++) {
        final line = lines[i];
        if (_isPaymentStop(line)) break;
        final m = t.amountPattern.firstMatch(line);
        if (m == null) continue;
        final remainder = line.replaceFirst(m.group(0)!, '').trim();
        if (t.letterTokens(remainder).any((w) => w.length >= 2)) continue;
        amounts.add(t.parseItalianAmount(m.group(1)!));
      }
    }
    var k = 0;
    for (final item in items) {
      if (k >= amounts.length) break;
      if (item.price != null) continue;
      item.price = amounts[k];
      k++;
    }
  }

  static double _centerY(LayoutRow row) {
    final b = row.box;
    if (b == null) {
      return row.indices.isEmpty ? 0 : row.indices.first.toDouble();
    }
    return (b.top + b.bottom) / 2;
  }

  static bool _isEurMarker(String line) {
    if (t.amountPattern.hasMatch(line)) return false;
    final norm = line.replaceAll(RegExp(r'[^a-zA-Z€]'), '').toUpperCase();
    return norm == 'EUR' || norm == '€' || norm == 'EURO';
  }

  static final _paymentStopWords = {
    'debit',
    'mastercard',
    'maestro',
    'visa',
    'bancomat',
    'pagobancomat',
  };

  static bool _isPaymentStop(String line) {
    final key = t.keywordForm(line);
    if (t.totalKeywordPattern.hasMatch(key) ||
        t.subtotalPattern.hasMatch(key) ||
        t.restoPattern.hasMatch(line.toUpperCase())) {
      return true;
    }
    return t.letterTokens(line).any(_paymentStopWords.contains);
  }

  /// Vertical band gap between two layout rows, in line heights
  /// (0 when the bands touch or overlap). Falls back to index distance
  /// when boxes are missing (samples/tests): one row step ≈ half line.
  static double _rowGapY(List<LayoutRow> rows, int a, int b) {
    final ba = rows[a].box;
    final bb = rows[b].box;
    if (ba == null || bb == null) return (a - b).abs() * 0.5;
    final top = ba.top > bb.top ? ba.top : bb.top;
    final bottom = ba.bottom < bb.bottom ? ba.bottom : bb.bottom;
    final overlap = bottom - top;
    if (overlap >= 0) return 0;
    final ha = ba.height <= 0 ? 40.0 : ba.height;
    final hb = bb.height <= 0 ? 40.0 : bb.height;
    final maxH = ha > hb ? ha : hb;
    return -overlap / maxH; // gap in line heights
  }

  /// Attaches one fragment row to the nearest priced item (band gap ≤
  /// ~1 line, above preferred). Returns true when attached.
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
      final gap = _rowGapY(rows, items[j].row, rowIdx);
      if (gap > 1.0) continue;
      if (best < 0 ||
          (items[j].row <= rowIdx &&
              (items[best].row > rowIdx ||
                  _rowGapY(rows, items[best].row, rowIdx) > gap))) {
        best = j;
      }
    }
    if (best < 0) return false;
    if (items[best].row <= rowIdx) {
      items[best].desc = '${items[best].desc} $text';
    } else {
      items[best].desc = '$text ${items[best].desc}';
    }
    items[best].confidence =
        _minConf(items[best].confidence, rows[rowIdx].confidence);
    return true;
  }

  /// Fragment attach: a short fragment row next to a priced item (band
  /// gap ≤ ~1 line, above preferred) is its continuation ("plast ica"),
  /// not a product. Full descs never merge this way — only fragments.
  static void _attachFragments(List<_RawItem> items, List<LayoutRow> rows) {
    bool isFragment(_RawItem e) =>
        e.price == null && e.desc.trim().length < 15;
    for (var k = 0; k < items.length; k++) {
      if (!isFragment(items[k])) continue;
      var best = -1;
      for (var j = k - 1; j >= 0 && k - j <= 3; j--) {
        if (items[j].price == null) continue;
        if (_rowGapY(rows, items[k].row, items[j].row) > 1.0) continue;
        best = j;
        break;
      }
      if (best < 0) {
        for (var j = k + 1;
            j < items.length && j - k <= 3;
            j++) {
          if (items[j].price == null) continue;
          if (_rowGapY(rows, items[j].row, items[k].row) > 1.0) continue;
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
      items[best].confidence = _minConf(items[best].confidence, items[k].confidence);
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
  _RawItem(this.desc, this.price, this.row, {this.confidence});
  String desc;
  double? price;
  final int row;
  double? confidence;
}

class _RowBuild {
  _RowBuild(this.top, this.bottom, int firstIdx) : indices = [firstIdx];
  double top;
  double bottom;
  final List<int> indices;
}
