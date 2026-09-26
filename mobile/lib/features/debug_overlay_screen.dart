/// Dev-only overlay (issue #9): the image with the parser's boxes drawn
/// on top, each colored by its [RowKind], plus the segmented items with
/// their prices and OCR confidence. This is what makes "righe mischiate /
/// prezzo sulla riga sbagliata" visible. Never reached in release builds
/// (the entry point is gated by `kDebugMode`).
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/receipt_layout.dart';

class DebugOverlayScreen extends StatefulWidget {
  const DebugOverlayScreen({
    super.key,
    required this.imagePath,
    required this.text,
    required this.geometry,
    required this.total,
  });

  final String imagePath;
  final String text;
  final List<LineGeometry?> geometry;
  final double total;

  @override
  State<DebugOverlayScreen> createState() => _DebugOverlayScreenState();
}

class _DebugOverlayScreenState extends State<DebugOverlayScreen> {
  ui.Image? _image;
  List<({LayoutRow row, RowKind kind})> _rows = const [];
  List<SegmentedItem> _items = const [];

  @override
  void initState() {
    super.initState();
    // Parsing is synchronous and must not wait on image decoding, which
    // can hang in a headless test environment.
    final lines = widget.text.split('\n').map((l) => l.trim()).toList();
    _rows = ReceiptLayoutParser.typedRows(lines, widget.geometry);
    _items = ReceiptLayoutParser.parseLines(
      lines,
      widget.geometry,
      widget.total,
    ).items;
    _loadImage();
  }

  Future<void> _loadImage() async {
    ui.Image? image;
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
    } catch (_) {
      image = null;
    }
    if (!mounted || image == null) return;
    setState(() => _image = image);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      appBar: AppBar(title: const Text('Debug overlay')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (image != null)
            AspectRatio(
              aspectRatio: image.width / image.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(widget.imagePath), fit: BoxFit.fill),
                  CustomPaint(
                    painter: _BoxesPainter(
                      rows: _rows,
                      imageWidth: image.width.toDouble(),
                      imageHeight: image.height.toDouble(),
                    ),
                  ),
                ],
              ),
            )
          else
            const Text('Immagine non decodificabile'),
          const SizedBox(height: 8),
          const Text('Righe (colore = tipo)', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 12,
            children: [
              for (final k in RowKind.values)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 12, height: 12, color: _colorFor(k)),
                  const SizedBox(width: 4),
                  Text(k.name),
                ]),
            ],
          ),
          const Divider(),
          const Text('Item (descrizione — prezzo — conf)', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final e in _items)
            ListTile(
              dense: true,
              title: Text(e.description),
              subtitle: e.isLowConfidence ? const Text('OCR incerta') : null,
              trailing: Text(
                '${e.price?.toStringAsFixed(2) ?? '-'}  '
                '${e.confidence?.toStringAsFixed(2) ?? '-'}',
              ),
            ),
        ],
      ),
    );
  }
}

Color _colorFor(RowKind kind) => switch (kind) {
  RowKind.bodyStart => Colors.purple,
  RowKind.trailer => Colors.red,
  RowKind.priced => Colors.green,
  RowKind.bare => Colors.teal,
  RowKind.desc => Colors.blue,
  RowKind.fragment => Colors.orange,
  RowKind.adjustment => Colors.brown,
  RowKind.noise => Colors.grey,
};

class _BoxesPainter extends CustomPainter {
  _BoxesPainter({
    required this.rows,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<({LayoutRow row, RowKind kind})> rows;
  final double imageWidth;
  final double imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / imageWidth;
    final sy = size.height / imageHeight;
    for (final r in rows) {
      final box = r.row.box;
      if (box == null) continue;
      final rect = Rect.fromLTRB(
        box.left * sx,
        box.top * sy,
        box.right * sx,
        box.bottom * sy,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _colorFor(r.kind);
      canvas.drawRect(rect, paint);
      final tp = TextPainter(
        text: TextSpan(
          text: r.kind.name,
          style: TextStyle(
            color: _colorFor(r.kind),
            fontSize: math.max(8, math.min(14, rect.height * 0.6)),
            backgroundColor: Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left, math.max(0, rect.top - tp.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _BoxesPainter old) =>
      old.rows != rows ||
      old.imageWidth != imageWidth ||
      old.imageHeight != imageHeight;
}
