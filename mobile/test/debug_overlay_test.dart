import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai/core/receipt_layout.dart';
import 'package:receipt_ai/features/debug_overlay_screen.dart';

// 1x1 white PNG.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// Axis-aligned line geometry with explicit corners, as ML Kit provides
/// (keeps the de-skew on true geometry, not the pair estimator).
LineGeometry _g(double l, double t, double r, double b) => LineGeometry(
  Rect.fromLTRB(l, t, r, b),
  corners: [
    Offset(l, t),
    Offset(r, t),
    Offset(r, b),
    Offset(l, b),
  ],
);

void main() {
  testWidgets('debug overlay renders boxes, legend and segmented item',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('overlay');
    final file = File('${dir.path}/photo.png')
      ..writeAsBytesSync(base64Decode(_png1x1));

    const text =
        'CONAD SUPERSTORE\nP.IVA 01234567890\nARTICOLI\nLATTE INTERO\n1,49\nTOTALE COMPLESSIVO 1,49';
    final geometry = <LineGeometry?>[
      _g(0, 0, 200, 18),
      _g(0, 25, 200, 43),
      _g(0, 50, 120, 68),
      _g(0, 80, 150, 98),
      _g(250, 80, 300, 98),
      _g(0, 140, 260, 158),
    ];

    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DebugOverlayScreen(
          imagePath: file.path,
          text: text,
          geometry: geometry,
          total: 1.49,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debug overlay'), findsOneWidget);
    expect(find.text('Righe (colore = tipo)'), findsOneWidget);
    expect(find.text('LATTE INTERO'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
