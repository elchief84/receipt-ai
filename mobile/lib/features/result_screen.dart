import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/classify.dart';
import '../core/feedback.dart';
import '../core/history.dart';
import '../core/normalize.dart';
import '../core/pipeline.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.feedback,
    required this.pipeline,
    required this.history,
  });

  final TransactionResult result;
  final FeedbackLog feedback;
  final ReceiptPipeline pipeline;
  final HistoryLog history;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late String _category;
  var _showOcr = false;

  @override
  void initState() {
    super.initState();
    _category = widget.result.category;
  }

  void _confirm(bool corrected) {
    widget.feedback.record(
      FeedbackEntry(
        originalCategory: widget.result.category,
        correctedCategory: _category,
        merchantNormalized: widget.result.merchantNormalized,
        total: widget.result.total,
        modelVersion: widget.result.modelVersion,
        timestamp: DateTime.now(),
      ),
    );
    widget.history.add(widget.result.copyWith(category: _category));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          corrected
              ? 'Correzione registrata: $_category'
              : 'Confermato: $_category',
        ),
      ),
    );
  }

  Future<void> _changeCategory() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change category'),
        children: expenseCategories
            .map(
              (c) => SimpleDialogOption(
                key: Key('category-$c'),
                onPressed: () => Navigator.of(context).pop(c),
                child: Text(c),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      setState(() => _category = selected);
      _confirm(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final pct = (r.confidence * 100).toStringAsFixed(0);
    return Scaffold(
      appBar: AppBar(title: Text(r.merchantRaw)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '€${r.total.toStringAsFixed(2)}',
            key: const Key('total'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(_category, key: const Key('category')),
          Text(
            'Confidence $pct% (${levelFor(r.confidence).name})',
            key: const Key('confidence'),
          ),
          const SizedBox(height: 8),
          Text('Merchant: ${r.merchantNormalized} (${r.merchantType})'),
          Text('Date: ${r.date}'),
          if (r.itemDetails.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Dettaglio items'),
            ...r.itemDetails.asMap().entries.map(
              (e) => ListTile(
                key: Key('itemDetail-${e.key}'),
                dense: true,
                title: Text(
                  e.value.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${e.value.category} ${(e.value.confidence * 100).toStringAsFixed(0)}%',
                ),
              ),
            ),
          ],
          TextButton(
            key: const Key('toggleOcr'),
            onPressed: () => setState(() => _showOcr = !_showOcr),
            child: Text(_showOcr ? 'Nascondi testo OCR' : 'Mostra testo OCR'),
          ),
          if (_showOcr)
            SelectableText(r.ocrText, key: const Key('ocrText')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('copyOcr'),
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: r.ocrText));
              } catch (_) {}
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testo OCR copiato')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copia testo OCR'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                key: const Key('correct'),
                onPressed: () => _confirm(false),
                child: const Text('Correct'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('changeCategory'),
                onPressed: _changeCategory,
                child: const Text('Change category'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
