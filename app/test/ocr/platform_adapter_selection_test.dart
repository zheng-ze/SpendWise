import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ocr/platform_adapter_selection.dart';

void main() {
  group('selectPlatformAdapter', () {
    test('returns the first non-null candidate', () {
      final result = selectPlatformAdapter<int>(<int? Function()>[
        () => null,
        () => 2,
        () => 3,
      ]);

      expect(result, 2);
    });

    test('returns null when every candidate is null', () {
      final result = selectPlatformAdapter<int?>(<int? Function()>[
        () => null,
        () => null,
      ]);

      expect(result, isNull);
    });
  });
}
