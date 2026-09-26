/// Pre-OCR image quality gate (issue #15).
///
/// A blurry or tiny photo makes every downstream stage guess; better to
/// tell the user "riprova con più luce" than to emit garbage. Two signals:
/// resolution (raw pixels) and focus (variance of the Laplacian on a
/// grayscale, downscaled frame). Thresholds are configurable constants;
/// the defaults are calibrated for the frame produced by [assessFile].
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Minimum source resolution accepted.
const minImageWidth = 480;
const minImageHeight = 480;

/// Minimum focus score (Laplacian variance) on the assessment frame.
/// Lower = blurrier. Empirically tuned on the downscaled frame; tune on
/// the debug corpus (docs/debug-corpus.md).
const minFocusScore = 45.0;

/// Frame width the image is downscaled to before scoring, so the focus
/// threshold is scale-independent of camera resolution.
const assessmentFrameWidth = 640;

class ImageQualityResult {
  const ImageQualityResult({
    required this.ok,
    required this.width,
    required this.height,
    required this.focus,
    this.reason,
  });

  final bool ok;
  final int width;
  final int height;
  final double focus;

  /// Human-readable reason when [ok] is false.
  final String? reason;
}

class ImageQuality {
  /// Scores a raw RGBA frame (as produced by the codec). Pure, no I/O:
  /// the seam tests drive.
  static ImageQualityResult assessRgba(
    Uint8List rgba,
    int width,
    int height,
  ) {
    if (width < minImageWidth || height < minImageHeight) {
      return ImageQualityResult(
        ok: false,
        width: width,
        height: height,
        focus: 0,
        reason: 'Risoluzione troppo bassa',
      );
    }
    final gray = _toGray(rgba, width, height);
    final focus = _laplacianVariance(gray, width, height);
    if (focus < minFocusScore) {
      return ImageQualityResult(
        ok: false,
        width: width,
        height: height,
        focus: focus,
        reason: 'Foto sfocata',
      );
    }
    return ImageQualityResult(
      ok: true,
      width: width,
      height: height,
      focus: focus,
    );
  }

  /// Decodes [path] downscaled to [assessmentFrameWidth] and scores it.
  /// Returns null when the image cannot be decoded (caller lets OCR try
  /// anyway rather than blocking on a decoding hiccup).
  static Future<ImageQualityResult?> assessFile(String path) async {
    try {
      final data = await ui.ImmutableBuffer.fromFilePath(path);
      final descriptor = await ui.ImageDescriptor.encoded(data);
      final targetW = descriptor.width > assessmentFrameWidth
          ? assessmentFrameWidth
          : descriptor.width;
      final codec = await descriptor.instantiateCodec(targetWidth: targetW);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;
      return assessRgba(
        byteData.buffer.asUint8List(),
        image.width,
        image.height,
      );
    } catch (_) {
      return null;
    }
  }

  static Uint8List _toGray(Uint8List rgba, int width, int height) {
    final gray = Uint8List(width * height);
    for (var i = 0; i < width * height; i++) {
      final r = rgba[i * 4];
      final g = rgba[i * 4 + 1];
      final b = rgba[i * 4 + 2];
      // Integer luma (ITU-R BT.601), cheap and good enough for focus.
      gray[i] = ((r * 299 + g * 587 + b * 114) ~/ 1000) & 0xff;
    }
    return gray;
  }

  /// Variance of the 4-neighbour Laplacian over the interior pixels.
  /// Sharp edges -> large variance; a blurred frame flattens toward 0.
  static double _laplacianVariance(Uint8List gray, int width, int height) {
    if (width < 3 || height < 3) return 0;
    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var y = 1; y < height - 1; y++) {
      final row = y * width;
      for (var x = 1; x < width - 1; x++) {
        final i = row + x;
        final lap = 4 * gray[i] -
            gray[i - 1] -
            gray[i + 1] -
            gray[i - width] -
            gray[i + width];
        sum += lap;
        sumSq += lap * lap;
        n++;
      }
    }
    if (n == 0) return 0;
    final mean = sum / n;
    return sumSq / n - mean * mean;
  }
}
