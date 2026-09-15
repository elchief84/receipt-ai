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
  late List<ItemClassification> _items;
  var _showOcr = false;

  @override
  void initState() {
    super.initState();
    _category = widget.result.category;
    _items = List.of(widget.result.itemDetails);
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
    widget.history.add(
      widget.result.copyWith(category: _category, itemDetails: _items),
    );
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

  Future<String?> _pickCategory(String title) => showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
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

  Future<void> _correctItem(int index) async {
    final item = _items[index];
    final messenger = ScaffoldMessenger.of(context);
    final selected = await _pickCategory(item.description);
    if (selected == null) return;
    setState(() {
      _items[index] = ItemClassification(
        description: item.description,
        category: selected,
        confidence: item.confidence,
        price: item.price,
      );
    });
    widget.feedback.record(
      FeedbackEntry(
        originalCategory: item.category ?? 'unknown',
        correctedCategory: selected,
        merchantNormalized: widget.result.merchantNormalized,
        total: item.price ?? 0.0,
        modelVersion: widget.result.modelVersion,
        timestamp: DateTime.now(),
        itemDescription: item.description,
      ),
    );
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Correzione registrata: $selected'),
        ),
      );
    }
  }

  Future<void> _changeCategory() async {
    final selected = await _pickCategory('Change category');
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
          if (r.sumCheck == true)
            const Row(
              key: Key('sumOk'),
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Dettaglio verificato'),
              ],
            ),
          if (r.sumCheck == false)
            const Row(
              key: Key('sumWarn'),
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text('Dettaglio da verificare'),
              ],
            ),
          const SizedBox(height: 8),
          Text('Merchant: ${r.merchantNormalized} (${r.merchantType})'),
          Text('Date: ${r.date}'),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Dettaglio items'),
            ..._items.asMap().entries.map(
              (e) {
                final parts = <String>[];
                if (e.value.price != null) {
                  parts.add('€${e.value.price!.toStringAsFixed(2)}');
                }
                parts.add(e.value.category ?? unknownItemCategoryLabel);
                return ListTile(
                  key: Key('itemDetail-${e.key}'),
                  dense: true,
                  title: Text(
                    e.value.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    parts.join(' · '),
                    key: Key('itemDetail-price-${e.key}'),
                    style: e.value.isUnknown
                        ? const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          )
                        : null,
                  ),
                  onTap: () => _correctItem(e.key),
                );
              },
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
