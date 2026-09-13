/// Classifier seam: classify() -> ClassificationResult.
/// The app never knows ML details; two impls: keyword fallback + JSON logistic.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'normalize.dart';

/// Configurable confidence thresholds (ADR: never hardcode in the model).
const highConfidenceThreshold = 0.7;
const mediumConfidenceThreshold = 0.45;

enum ConfidenceLevel { high, medium, low }

ConfidenceLevel levelFor(double confidence) {
  if (confidence >= highConfidenceThreshold) return ConfidenceLevel.high;
  if (confidence >= mediumConfidenceThreshold) return ConfidenceLevel.medium;
  return ConfidenceLevel.low;
}

class ClassificationInput {
  ClassificationInput({
    required this.merchantNormalized,
    required this.merchantType,
    required this.ocrText,
    required this.items,
  });
  final String merchantNormalized;
  final String merchantType;
  final String ocrText;
  final List<String> items;
}

class ClassificationResult {
  ClassificationResult({
    required this.category,
    required this.confidence,
    required this.modelVersion,
  });
  final String category;
  final double confidence;
  final String modelVersion;

  ConfidenceLevel get level => levelFor(confidence);
}

abstract class Classifier {
  ClassificationResult classify(ClassificationInput input);
}

/// Keyword fallback used when the JSON model asset is absent.
class KeywordClassifier implements Classifier {
  static const _keywords = {
    'groceries': ['pane', 'latte', 'pasta', 'supermercato', 'conad', 'esselunga', 'macelleria', 'carne', 'panetteria', 'pescheria'],
    'restaurants': ['pizza', 'ristorante', 'pizzeria', 'cappuccino', 'bar'],
    'transport': ['benzina', 'carburante', 'eni', 'pedaggio', 'trenitalia', 'biglietto'],
    'health': ['farmacia', 'dentifricio', 'parafarmacia'],
    'shopping': ['maglietta', 'lampadina', 'ikea', 'ovs'],
    'technology': ['cuffie', 'bluetooth', 'usb', 'cavo', 'mediaworld'],
    'leisure_travel': ['hotel', 'cinema', 'pernottamento'],
    'services': ['bolletta', 'enel', 'poste', 'raccomandata'],
  };

  @override
  ClassificationResult classify(ClassificationInput input) {
    final text = normalizeName(
      '${input.merchantNormalized} ${input.merchantType} ${input.ocrText} ${input.items.join(' ')}',
    );
    var best = 'other';
    var bestHits = 0;
    _keywords.forEach((category, words) {
      final hits = words.where(text.contains).length;
      if (hits > bestHits) {
        bestHits = hits;
        best = category;
      }
    });
    return ClassificationResult(
      category: best,
      confidence: bestHits > 0 ? 0.5 : 0.2,
      modelVersion: 'keyword-v1',
    );
  }
}

/// LogisticRegression TF-IDF port: same math as ml/training/train_logreg.py.
/// tokenizer_spec normalize_name+split-v1 must match, else parity breaks.
class JsonLogisticClassifier implements Classifier {
  JsonLogisticClassifier(this._model, this.modelVersion);

  final Map<String, dynamic> _model;
  final String modelVersion;

  static Future<JsonLogisticClassifier> fromAssets(
    String assetPath,
    String version,
  ) async {
    // NB: rootBundle.load (not loadString): loadString offloads >10KB
    // decoding to an isolate via compute(), which hangs under flutter test.
    // Synchronous utf8.decode of a ~100KB asset costs single-digit ms.
    final data = await rootBundle.load(assetPath);
    final raw = utf8.decode(data.buffer.asUint8List());
    return JsonLogisticClassifier(json.decode(raw), version);
  }

  /// Test/entrypoint constructor from an already-decoded model map.
  factory JsonLogisticClassifier.fromMap(Map<String, dynamic> model, String version) =>
      JsonLogisticClassifier(model, version);

  @override
  ClassificationResult classify(ClassificationInput input) {
    final text =
        '${input.merchantNormalized} ${input.merchantType} ${input.ocrText} ${input.items.join(' ')}';
    final terms = normalizeName(text).split(' ');
    final vocab = (_model['vocabulary'] as Map).cast<String, int>();
    final idf = (_model['idf'] as List).cast<num>();
    final counts = <int, int>{};
    for (final term in terms) {
      final idx = vocab[term];
      if (idx != null) counts[idx] = (counts[idx] ?? 0) + 1;
    }
    final weighted = <int, double>{
      for (final e in counts.entries) e.key: e.value * idf[e.key].toDouble(),
    };
    final norm =
        math.sqrt(weighted.values.fold(0.0, (a, b) => a + b * b));
    final intercept = (_model['intercept'] as List).cast<num>();
    final coef = (_model['coef'] as List)
        .map((row) => (row as List).cast<num>())
        .toList();
    final classes = (_model['classes'] as List).cast<String>();
    final scores = intercept.map((e) => e.toDouble()).toList();
    weighted.forEach((idx, value) {
      final tfidf = value / (norm == 0 ? 1.0 : norm);
      for (var c = 0; c < scores.length; c++) {
        scores[c] += coef[c][idx].toDouble() * tfidf;
      }
    });
    late final String category;
    var bestIdx = 0;
    if (scores.length == 1) {
      category = scores[0] > 0 ? classes[1] : classes[0];
    } else {
      for (var c = 1; c < scores.length; c++) {
        if (scores[c] > scores[bestIdx]) bestIdx = c;
      }
      category = classes[bestIdx];
    }
    // Softmax confidence over scores.
    final maxScore = scores.reduce(math.max);
    final exps = scores.map((s) => math.exp(s - maxScore)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    final confidence = scores.length == 1
        ? (1.0 / (1.0 + math.exp(-scores[0].abs())))
        : exps[bestIdx] / sumExp;
    return ClassificationResult(
      category: category,
      confidence: confidence,
      modelVersion: modelVersion,
    );
  }
}
