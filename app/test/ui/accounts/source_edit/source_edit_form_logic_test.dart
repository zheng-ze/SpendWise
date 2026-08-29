import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/accounts/source_edit/source_edit_form_logic.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  const holderID = 'a0000000-0000-0000-0000-000000000001';

  group('canSaveSourceEditForm', () {
    test('requires a non-blank name', () {
      expect(canSaveSourceEditForm(name: '  ', balance: Decimal.zero), isFalse);
    });

    test('requires a parsed balance', () {
      expect(canSaveSourceEditForm(name: 'Wallet', balance: null), isFalse);
      expect(
        canSaveSourceEditForm(name: 'Wallet', balance: Decimal.zero),
        isTrue,
      );
    });
  });

  group('balanceAdjustmentEntry', () {
    test('no entry when the balance is unchanged', () {
      final entry = balanceAdjustmentEntry(
        enteredBalance: dec('100'),
        currentBalance: dec('100'),
        holderID: holderID,
      );

      expect(entry, isNull);
    });

    test('posts a positive delta for a higher entered balance', () {
      final entry = balanceAdjustmentEntry(
        enteredBalance: dec('150'),
        currentBalance: dec('100'),
        holderID: holderID,
      );

      expect(entry, isNotNull);
      expect(entry!.amount, dec('50'));
      expect(entry.sourceID, holderID);
      expect(entry.includeInAnalysis, isFalse);
    });

    test('posts a negative delta for a lower entered balance', () {
      final entry = balanceAdjustmentEntry(
        enteredBalance: dec('40'),
        currentBalance: dec('100'),
        holderID: holderID,
      );

      expect(entry, isNotNull);
      expect(entry!.amount, dec('-60'));
      expect(entry.sourceID, holderID);
      expect(entry.includeInAnalysis, isFalse);
    });
  });
}
