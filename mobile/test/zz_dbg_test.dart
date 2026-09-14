import 'package:flutter_test/flutter_test.dart';
import 'fixtures/action_real.dart';
import 'package:receipt_ai/core/receipt_layout.dart';

void main() {
  test('debug rows', () {
    final rows = ReceiptLayoutParser.debugRows(actionRealTexts, actionRealBoxes);
    for (var i = 0; i < rows.length; i++) {
      // ignore: avoid_print
      print('ROW $i [${rows[i].$2.name}] ${rows[i].$1}');
    }
  });
}
