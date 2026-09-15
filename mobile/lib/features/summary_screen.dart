import 'package:flutter/material.dart';

import '../core/history.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.history});

  final HistoryLog history;

  @override
  Widget build(BuildContext context) {
    final totals = history.totalsByCategory();
    final unknown = history.unknownItemCount;
    final max =
        totals.values.fold<double>(0, (a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('This month')),
      body: totals.isEmpty && unknown == 0
          ? const Center(child: Text('No expenses yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...totals.entries.map((e) {
                  final fraction = max == 0 ? 0.0 : e.value / max;
                  return ListTile(
                    key: Key('summary-${e.key}'),
                    title: Text(e.key),
                    subtitle: LinearProgressIndicator(value: fraction),
                    trailing: Text(
                      '€${e.value.toStringAsFixed(2)}',
                      key: Key('summary-total-${e.key}'),
                    ),
                  );
                }),
                // Count only, no money: transaction totals already account
                // for every euro — this is a data-quality signal (ADR-0010).
                if (unknown > 0)
                  ListTile(
                    key: const Key('summary-unknown'),
                    leading: const Icon(
                      Icons.help_outline,
                      color: Colors.grey,
                    ),
                    title: const Text('Voci da verificare'),
                    trailing: Text(
                      '$unknown',
                      key: const Key('summary-unknown-count'),
                    ),
                  ),
              ],
            ),
    );
  }
}
