import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/field_extraction_readiness.dart';

void main() {
  test('is true off the web, where every platform has its own extractor', () async {
    expect(await isFieldExtractionReady(), isTrue);
  });
}
