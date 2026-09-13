/// Merchant normalization against the embedded OSM gazetteer.
library;

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
    final csv = await rootBundle.loadString(assetPath);
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
    if (_gazetteer.containsKey(normalized)) {
      return NormalizedMerchant(
        rawName: merchantRaw,
        normalizedName: normalized,
        merchantType: _gazetteer[normalized]!,
      );
    }
    for (final entry in _gazetteer.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return NormalizedMerchant(
          rawName: merchantRaw,
          normalizedName: entry.key,
          merchantType: entry.value,
        );
      }
    }
    return NormalizedMerchant(
      rawName: merchantRaw,
      normalizedName: normalized,
      merchantType: 'other',
    );
  }
}
