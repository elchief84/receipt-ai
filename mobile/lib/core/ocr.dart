/// OCR seam: text extraction from a document image.
library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  OcrResult(this.text, {this.confidence = 1.0});
  final String text;
  final double confidence;
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
      final text = result.text.trim();
      // Heuristic: empty or tiny output means poor capture.
      final confidence = text.isEmpty
          ? 0.0
          : (text.length < 20 ? 0.3 : 0.9);
      return OcrResult(text, confidence: confidence);
    } finally {
      await recognizer.close();
    }
  }
}

/// Deterministic fake for widget/unit tests.
class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine(this.text, {this.confidence = 1.0});
  final String text;
  final double confidence;

  @override
  Future<OcrResult> recognize(String imagePath) async =>
      OcrResult(text, confidence: confidence);
}
