/// Merchant normalization against the embedded OSM gazetteer.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'normalize.dart';

class NormalizedMerchant {
  NormalizedMerchant({
    required this.rawName,
    required this.normalizedName,
    required this.merchantType,
  });
  final String rawName;
  final String normalizedName;
  final String merchantType;
}

class MerchantNormalizer {
  MerchantNormalizer(this._gazetteer);

  /// normalized_name -> merchant_type
  final Map<String, String> _gazetteer;

  static Future<MerchantNormalizer> fromAssets(String assetPath) async {
    // NB: rootBundle.load (not loadString), see JsonLogisticClassifier.
    final data = await rootBundle.load(assetPath);
    final csv = utf8.decode(data.buffer.asUint8List());
    final map = <String, String>{};
    for (final line in csv.split('\n').skip(1)) {
      final parts = line.split(',');
      if (parts.length < 4) continue;
      map[parts[1].trim()] = parts[2].trim();
    }
    return MerchantNormalizer(map);
  }

  NormalizedMerchant normalize(String merchantRaw) {
    final normalized = normalizeName(merchantRaw);
    if (normalized.isEmpty) {
      return NormalizedMerchant(
        rawName: merchantRaw,
        normalizedName: normalized,
        merchantType: 'other',
      );
    }
    final hit = _lookup(merchantRaw, normalized);
    return hit ??
        NormalizedMerchant(
          rawName: merchantRaw,
          normalizedName: normalized,
          merchantType: 'other',
        );
  }

  /// Scans all OCR lines for a gazetteer hit (exact first, then contains).
  /// Order summaries bury "Venduto da: Amazon.it" mid-text while line 1
  /// is header garbage — first line alone is not enough (ADR-0001 Amazon).
  NormalizedMerchant? findInLines(List<String> lines) {
    NormalizedMerchant? containsHit;
    for (final line in lines) {
      final normalized = normalizeName(line);
      if (normalized.isEmpty) continue;
      if (_gazetteer.containsKey(normalized)) {
        return NormalizedMerchant(
          rawName: line.trim(),
          normalizedName: normalized,
          merchantType: _gazetteer[normalized]!,
        );
      }
      containsHit ??= _containsMatch(line.trim(), normalized);
    }
    return containsHit;
  }

  NormalizedMerchant? _lookup(String raw, String normalized) {
    if (_gazetteer.containsKey(normalized)) {
      return NormalizedMerchant(
        rawName: raw,
        normalizedName: normalized,
        merchantType: _gazetteer[normalized]!,
      );
    }
    return _containsMatch(raw, normalized);
  }

  NormalizedMerchant? _containsMatch(String raw, String normalized) {
    final tokens = normalized.split(' ').where((t) => t.length >= 3).toSet();
    for (final entry in _gazetteer.entries) {
      final keyTokens =
          entry.key.split(' ').where((t) => t.length >= 3).toSet();
      if (tokens.intersection(keyTokens).isNotEmpty) {
        return NormalizedMerchant(
          rawName: raw,
          normalizedName: entry.key,
          merchantType: entry.value,
        );
      }
    }
    return null;
  }
}
