import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/extractor.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

/// Field-level eval harness (issue #12) over the local debug corpus
/// (ADR-0011 / docs/debug-corpus.md). The corpus is gitignored and may be
/// empty: the harness then records a zero-sample baseline and passes.
///
/// Layout of a sample:
///   `debug/[slug]/photo.jpg`
///   `debug/[slug]/ocr.log`        dump [OCR-TEXT] + [OCR-GEOM]
///   `debug/[slug]/expected.json`  merchant, total, items(description, price)
class _Sample {
  _Sample(this.slug, this.lineText, this.geoms, this.expected);
  final String slug;
  final List<String> lineText;
  final List<LineGeometry?> geoms;
  final Map<String, dynamic> expected;
}

void main() {
  test('field-level eval over the local debug corpus', () {
    final root = Directory(
      Platform.environment['DEBUG_CORPUS_DIR'] ?? '../debug',
    );
    final samples = <_Sample>[];
    if (root.existsSync()) {
      for (final d in root.listSync().whereType<Directory>()) {
        final s = _load(d);
        if (s != null) samples.add(s);
      }
    }
    final report = _runEval(samples);
    final out = File(
      Platform.environment['EVAL_OUT'] ?? '../docs/OCR_EVAL.md',
    );
    out.writeAsStringSync(report);
  });
}

_Sample? _load(Directory dir) {
  final log = File('${dir.path}/ocr.log');
  final exp = File('${dir.path}/expected.json');
  if (!log.existsSync() || !exp.existsSync()) return null;
  final text = log.readAsStringSync();
  final lines = _parseTextSection(text);
  final geoms = _parseGeomSection(text, lines);
  return _Sample(
    dir.uri.pathSegments.where((s) => s.isNotEmpty).last,
    lines,
    geoms,
    json.decode(exp.readAsStringSync()) as Map<String, dynamic>,
  );
}

/// `flutter run` prefixes every line with a logcat tag
/// (`I/flutter (12835): ...`): strip it so a pasted console dump parses
/// as if it were the raw `[OCR-…]` blocks.
final _logPrefix = RegExp(r'^\s*[A-Z]\/[^(]+\(\s*\d+\):\s?');

/// logcat de-duplicates repeated lines ("identical N line") and leaks
/// its own markers; both are dropped.
final _logNoise = RegExp(r'identical \d+ line|^\s*uid=\(');

/// Cleans one captured block: strip the logcat prefix, drop logcat noise,
/// trim trailing spaces, drop leading/trailing blanks. Applied identically
/// to the text and geometry blocks so they stay aligned 1:1.
List<String> _cleanBlock(String body) {
  final out = <String>[];
  for (final raw in body.split('\n')) {
    var line = raw.replaceFirst(_logPrefix, '');
    if (_logNoise.hasMatch(line)) continue;
    line = line.trimRight();
    out.add(line);
  }
  while (out.isNotEmpty && out.first.trim().isEmpty) {
    out.removeAt(0);
  }
  while (out.isNotEmpty && out.last.trim().isEmpty) {
    out.removeLast();
  }
  return out;
}

List<String> _parseTextSection(String log) {
  final start = log.indexOf('[OCR-TEXT-START]');
  final end = log.indexOf('[OCR-TEXT-END]');
  if (start < 0 || end < 0) return const [];
  return _cleanBlock(log.substring(start + '[OCR-TEXT-START]'.length, end));
}

/// Parses the `[OCR-GEOM]` block and aligns it to [textLines] by matching
/// the line text, not by index: logcat de-duplication can drop a line in
/// one block but not the other, and a strict 1:1 check would then throw
/// away ALL geometry (the Action two-column case). Unmatched text lines
/// get null geometry; leftover geometry is ignored.
List<LineGeometry?> _parseGeomSection(String log, List<String> textLines) {
  final start = log.indexOf('[OCR-GEOM-START]');
  final end = log.indexOf('[OCR-GEOM-END]');
  if (start < 0 || end < 0) return List.filled(textLines.length, null);
  final body = _cleanBlock(
    log.substring(start + '[OCR-GEOM-START]'.length, end),
  );
  final entries = <({String text, LineGeometry geom})>[];
  for (final line in body) {
    if (!line.startsWith('G ')) continue;
    // G <l> <t> <r> <b> | <angle> | <conf> | <text>
    final parts = line.substring(2).split('|');
    if (parts.length < 4) continue;
    final nums =
        parts[0].trim().split(RegExp(r'\s+')).map(double.tryParse).toList();
    if (nums.length < 4 || nums.any((n) => n == null)) continue;
    entries.add((
      text: parts.sublist(3).join('|').trim(),
      geom: LineGeometry(
        Rect.fromLTRB(nums[0]!, nums[1]!, nums[2]!, nums[3]!),
        angle: double.tryParse(parts[1].trim()),
        confidence: double.tryParse(parts[2].trim()),
        corners: const <Offset>[],
      ),
    ));
  }
  final result = List<LineGeometry?>.filled(textLines.length, null);
  var j = 0;
  for (var i = 0; i < textLines.length; i++) {
    final t = textLines[i].trim();
    // Bounded look-ahead: a stray logcat line ("2") must not scan to the
    // end (which would null out all the remaining geometry). Local drops
    // are absorbed, a real mismatch just leaves this line with no box.
    var found = -1;
    for (var k = j; k < entries.length && k < j + 5; k++) {
      if (entries[k].text == t) {
        found = k;
        break;
      }
    }
    if (found >= 0) {
      result[i] = entries[found].geom;
      j = found + 1;
    }
  }
  return result;
}

String _runEval(List<_Sample> samples) {
  var totalExact = 0;
  var sumOk = 0;
  var itemCountMatch = 0;
  var itemTp = 0, itemFp = 0, itemFn = 0;
  var cerSum = 0.0, cerN = 0;

  for (final s in samples) {
    final draft = TransactionExtractor().extract(s.lineText.join('\n'));
    final layout = ReceiptLayoutParser.parseLines(
      s.lineText,
      s.geoms,
      draft.total,
    );
    final expTotal = (s.expected['total'] as num).toDouble();
    if ((draft.total - expTotal).abs() <= 0.005) totalExact++;
    if (layout.sumOk == true) sumOk++;

    final expItems =
        ((s.expected['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final got = layout.items.where((e) => e.price != null).toList();
    if (got.length == expItems.length) itemCountMatch++;

    final used = <int>{};
    for (final e in expItems) {
      final ep = (e['price'] as num).toDouble();
      var best = -1;
      var bestSim = 0.0;
      for (var i = 0; i < got.length; i++) {
        if (used.contains(i)) continue;
        if ((got[i].price! - ep).abs() > 0.011) continue;
        final sim = _similarity(
          (e['description'] as String).toLowerCase(),
          got[i].description.toLowerCase(),
        );
        if (sim > bestSim) {
          bestSim = sim;
          best = i;
        }
      }
      if (best >= 0 && bestSim >= 0.6) {
        used.add(best);
        itemTp++;
        cerSum += 1.0 - bestSim;
        cerN++;
      } else {
        itemFn++;
      }
    }
    itemFp += got.length - used.length;
  }

  final n = samples.length;
  final precision = itemTp + itemFp == 0 ? 0.0 : itemTp / (itemTp + itemFp);
  final recall = itemTp + itemFn == 0 ? 0.0 : itemTp / (itemTp + itemFn);
  final f1 = precision + recall == 0
      ? 0.0
      : 2 * precision * recall / (precision + recall);
  double rate(int x) => n == 0 ? 0.0 : x / n;
  final cer = cerN == 0 ? 0.0 : cerSum / cerN;

  final buf = StringBuffer();
  buf.writeln('# OCR_EVAL.md — eval OCR/layout su corpus di debug');
  buf.writeln();
  buf.writeln('> Generato da `mobile/test/eval_corpus_test.dart` (issue #12).');
  buf.writeln('> Corpus locale gitignored (ADR-0011), mai training. Formato: `docs/debug-corpus.md`.');
  buf.writeln();
  buf.writeln('## Campioni');
  buf.writeln();
  buf.writeln('| campione | totale | sum-ok | item |');
  buf.writeln('|----------|:------:|:------:|:----:|');
  for (final s in samples) {
    final draft = TransactionExtractor().extract(s.lineText.join('\n'));
    final layout = ReceiptLayoutParser.parseLines(s.lineText, s.geoms, draft.total);
    final expTotal = (s.expected['total'] as num).toDouble();
    buf.writeln(
      '| ${s.slug} | ${(draft.total - expTotal).abs() <= 0.005 ? "OK" : "KO"} '
      '| ${layout.sumOk == true ? "OK" : "-"} '
      '| ${layout.items.where((e) => e.price != null).length} |',
    );
  }
  buf.writeln();
  buf.writeln('## Metriche (n = $n)');
  buf.writeln();
  buf.writeln('| metrica | valore |');
  buf.writeln('|---------|:------:|');
  buf.writeln('| Exact match totale | ${_pct(rate(totalExact))} |');
  buf.writeln('| Sum-consistency rate | ${_pct(rate(sumOk))} |');
  buf.writeln('| Item count match | ${_pct(rate(itemCountMatch))} |');
  buf.writeln('| Item precision | ${_pct(precision)} |');
  buf.writeln('| Item recall | ${_pct(recall)} |');
  buf.writeln('| Item F1 | ${_pct(f1)} |');
  buf.writeln('| CER medio (descrizioni) | ${(cer * 100).toStringAsFixed(1)}% |');
  buf.writeln();
  if (n == 0) {
    buf.writeln('_Nessun campione nel corpus: baseline vuota. '
        'Cattura una foto che fallisce (vedi docs/debug-corpus.md)._');
  }
  return buf.toString();
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

/// Normalized similarity in 0..1 based on edit distance.
double _similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final d = _levenshtein(a, b);
  final len = a.length > b.length ? a.length : b.length;
  return len == 0 ? 1 : 1 - d / len;
}

int _levenshtein(String a, String b) {
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = cur[j];
    }
  }
  return prev[b.length];
}
