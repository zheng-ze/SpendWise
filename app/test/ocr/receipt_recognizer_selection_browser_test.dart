@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ocr/ocr.dart';
import 'package:spendwise/ocr/receipt_recognizer_selection.dart';

void main() {
  test('picks TesseractTextRecognizer on the web branch', () {
    final recognizer = selectRecognizer(isWeb: true);

    expect(recognizer, isA<TesseractTextRecognizer>());
  });
}
