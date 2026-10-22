import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/pickers/symbol_picker.dart';

void main() {
  group('filterSymbolSections', () {
    const sections = {
      'Food & Drink': ['restaurant', 'local_cafe'],
      'Transport': ['directions_car', 'flight'],
      'Money': ['savings', 'attach_money'],
    };

    test('empty query returns every section unchanged', () {
      expect(filterSymbolSections(sections, ''), sections);
    });

    test('a trimmed case-insensitive term returns only matching symbols', () {
      final result = filterSymbolSections(sections, '  CAr  ');
      expect(result.keys, ['Transport']);
      expect(result['Transport'], ['directions_car']);
    });

    test('a query matching nothing returns no sections', () {
      expect(filterSymbolSections(sections, 'zzz'), isEmpty);
    });
  });
}
