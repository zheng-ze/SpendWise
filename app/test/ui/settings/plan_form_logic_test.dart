import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/settings/plan_form_logic.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  group('canSavePlanForm', () {
    test('rejects a blank name', () {
      expect(canSavePlanForm(name: '   ', amount: dec('10')), isFalse);
    });

    test('rejects a zero amount', () {
      expect(canSavePlanForm(name: 'Rent', amount: dec('0')), isFalse);
    });

    test('accepts a trimmed name and non-zero amount', () {
      expect(canSavePlanForm(name: 'Rent', amount: dec('10')), isTrue);
    });
  });

  group('applyOriginalSign', () {
    test('reapplies a negative sign regardless of the typed magnitude', () {
      final result = applyOriginalSign(
        magnitude: dec('75'),
        originalAmount: dec('-10'),
      );
      expect(result, dec('-75'));
    });

    test('keeps a positive sign for an originally-positive amount', () {
      final result = applyOriginalSign(
        magnitude: dec('75'),
        originalAmount: dec('10'),
      );
      expect(result, dec('75'));
    });
  });

  group('applyPickerResult', () {
    test('an explicit one-time choice keeps the current frequency', () {
      final result = applyPickerResult(RecurrenceFrequency.monthly, null);
      expect(result, RecurrenceFrequency.monthly);
    });

    test('a dismissed sheet also keeps the current frequency', () {
      // The picker itself collapses dismissal and an explicit one-time
      // choice to the same null return, so this exercises the same branch
      // as the case above.
      final result = applyPickerResult(RecurrenceFrequency.weekly, null);
      expect(result, RecurrenceFrequency.weekly);
    });

    test('a genuinely picked frequency replaces the current one', () {
      final result = applyPickerResult(
        RecurrenceFrequency.monthly,
        RecurrenceFrequency.yearly,
      );
      expect(result, RecurrenceFrequency.yearly);
    });
  });
}
