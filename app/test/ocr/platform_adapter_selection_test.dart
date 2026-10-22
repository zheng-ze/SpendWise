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

    test('evaluates candidates in order until the first hit', () {
      final order = <int>[];
      final result = selectPlatformAdapter<int>(<int? Function()>[
        () {
          order.add(1);
          return null;
        },
        () {
          order.add(2);
          return 2;
        },
        () {
          order.add(3);
          return 3;
        },
      ]);

      expect(result, 2);
      expect(order, [1, 2]);
    });

    test('never evaluates a later candidate after an earlier one succeeds', () {
      var laterEvaluated = false;
      final result = selectPlatformAdapter<int>(<int? Function()>[
        () => 1,
        () {
          laterEvaluated = true;
          return 2;
        },
      ]);

      expect(result, 1);
      expect(laterEvaluated, isFalse);
    });

    test('returns null when every candidate is null', () {
      final result = selectPlatformAdapter<int?>(<int? Function()>[
        () => null,
        () => null,
      ]);

      expect(result, isNull);
    });

    test('returns null for an empty candidate list', () {
      final result = selectPlatformAdapter<int>(<int? Function()>[]);

      expect(result, isNull);
    });
  });
}
