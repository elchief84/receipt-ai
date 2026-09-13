import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/feedback.dart';
import '../core/history.dart';
import '../core/ocr.dart';
import '../core/pipeline.dart';
import 'result_screen.dart';
import 'samples.dart';
import 'summary_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.pipeline,
    required this.ocr,
    required this.feedback,
    required this.history,
  });

  final ReceiptPipeline pipeline;
  final OcrEngine ocr;
  final FeedbackLog feedback;
  final HistoryLog history;

  Future<void> _fromImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image == null) return;
    if (!context.mounted) return;
    final result = await ocr.recognize(image.path);
    debugPrint('[OCR-TEXT-START]\n${result.text}\n[OCR-TEXT-END]');
    if (!context.mounted) return;
    if (result.confidence < 0.5 || result.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto poco leggibile, riprova con più luce'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: pipeline.run(result.text),
          feedback: feedback,
          pipeline: pipeline,
          history: history,
        ),
      ),
    );
  }

  void _fromSample(BuildContext context, String text) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: pipeline.run(text),
          feedback: feedback,
          pipeline: pipeline,
          history: history,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Classifier')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            key: const Key('takePhoto'),
            onPressed: () => _fromImage(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take photo'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            key: const Key('chooseImage'),
            onPressed: () => _fromImage(context, ImageSource.gallery),
            icon: const Icon(Icons.image),
            label: const Text('Choose image'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            key: const Key('summary'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SummaryScreen(history: history),
              ),
            ),
            icon: const Icon(Icons.pie_chart),
            label: const Text('Summary'),
          ),
          const SizedBox(height: 24),
          const Text('Use sample receipt'),
          ...sampleReceipts.map(
            (s) => ListTile(
              key: Key('sample-${s.name}'),
              title: Text(s.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _fromSample(context, s.text),
            ),
          ),
        ],
      ),
    );
  }
}
