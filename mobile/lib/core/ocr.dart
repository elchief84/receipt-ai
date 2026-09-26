/// OCR seam: text extraction from a document image.
library;

import 'dart:ui' show Offset, Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  OcrResult(this.text, {this.confidence = 1.0, this.lines = const []});
  final String text;
  final double confidence;

  /// One entry per visual line, same order as text.split('\n').
  /// Boxes share one coordinate space: only relative overlap is used,
  /// so pixel and normalized units both work.
  final List<OcrLine> lines;
}

class OcrLine {
  OcrLine(
    this.text,
    this.box, {
    this.confidence,
    this.angle,
    this.corners = const [],
  });

  final String text;

  /// Axis-aligned bounding box (ML Kit `boundingBox`).
  final Rect box;

  /// Per-line recognition confidence (ML Kit, 0..1), null when absent.
  final double? confidence;

  /// Per-line rotation in degrees (ML Kit `angle`), null when absent.
  final double? angle;

  /// The four rotated corners, clockwise from top-left (ML Kit
  /// `cornerPoints`). Empty when absent. Preserves tilt/quad geometry the
  /// axis-aligned [box] flattens.
  final List<Offset> corners;

  /// Vertical overlap ratio over the smaller height (0..1).
  double yOverlap(OcrLine other) {
    final top = box.top > other.box.top ? box.top : other.box.top;
    final bottom =
        box.bottom < other.box.bottom ? box.bottom : other.box.bottom;
    final overlap = bottom - top;
    if (overlap <= 0) return 0;
    final minHeight = box.height < other.box.height
        ? box.height
        : other.box.height;
    if (minHeight <= 0) return 0;
    return overlap / minHeight;
  }
}

abstract class OcrEngine {
  Future<OcrResult> recognize(String imagePath);
}

class MlKitOcrEngine implements OcrEngine {
  @override
  Future<OcrResult> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      // Build text AND boxes from the same traversal so that
      // text.split('\n') aligns 1:1 with lines.
      final lines = <OcrLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          lines.add(
            OcrLine(
              line.text.trim(),
              line.boundingBox,
              confidence: line.confidence,
              angle: line.angle,
              corners: [
                for (final p in line.cornerPoints)
                  Offset(p.x.toDouble(), p.y.toDouble()),
              ],
            ),
          );
        }
      }
      final text = lines.map((l) => l.text).join('\n').trim();
      final confidence = text.isEmpty
          ? 0.0
          : (text.length < 20 ? 0.3 : 0.9);
      return OcrResult(text, confidence: confidence, lines: lines);
    } finally {
      await recognizer.close();
    }
  }
}

/// Deterministic fake for widget/unit tests.
class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine(
    this.text, {
    this.confidence = 1.0,
    this.geometry,
    this.angles,
    this.confidences,
  });

  final String text;
  final double confidence;

  /// Optional boxes aligned 1:1 with text.split('\n'); stacked full-width
  /// fallbacks are generated when absent.
  final List<Rect>? geometry;

  /// Optional per-line ML Kit angles (degrees), aligned with the rows.
  final List<double?>? angles;

  /// Optional per-line ML Kit confidences, aligned with the rows.
  final List<double?>? confidences;

  @override
  Future<OcrResult> recognize(String imagePath) async {
    final rows = text.split('\n');
    final lines = <OcrLine>[];
    for (var i = 0; i < rows.length; i++) {
      final box = (geometry != null && i < geometry!.length)
          ? geometry![i]
          : Rect.fromLTWH(0, i.toDouble(), 100, 1);
      lines.add(
        OcrLine(
          rows[i],
          box,
          angle: (angles != null && i < angles!.length) ? angles![i] : null,
          confidence: (confidences != null && i < confidences!.length)
              ? confidences![i]
              : null,
        ),
      );
    }
    return OcrResult(text, confidence: confidence, lines: lines);
  }
}
