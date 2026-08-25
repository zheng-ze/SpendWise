import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {checking.id: MoneySource.account(checking)},
        entries: entries,
      ),
    );
  }

  group('new-entry mode prefill', () {
    test('seeds amount/name/date controllers from initial* params', () {
      final controller = EntryFormController(
        ledger: buildLedger(),
        initialName: 'Cafe Luna',
        initialAmount: dec('12.50'),
        initialDate: DateTime.utc(2026, 3, 4),
      );

      expect(controller.nameController.text, 'Cafe Luna');
      expect(controller.amountController.text, '12.50');
      expect(controller.date, DateTime.utc(2026, 3, 4));

      controller.dispose();
    });

    test(
      'falls back to blank/today defaults when initial* params are omitted',
      () {
        final controller = EntryFormController(ledger: buildLedger());

        expect(controller.nameController.text, '');
        expect(controller.amountController.text, '');

        controller.dispose();
      },
    );

    test('prefilled fields stay editable', () {
      final controller = EntryFormController(
        ledger: buildLedger(),
        initialName: 'Cafe Luna',
        initialAmount: dec('12.50'),
      );

      controller.nameController.text = 'Corrected Name';
      controller.amountController.text = '9.99';

      expect(controller.nameController.text, 'Corrected Name');
      expect(controller.amountController.text, '9.99');

      controller.dispose();
    });
  });

  group('applyScanResult', () {
    test('fills name/amount/date on an already-open new-entry controller', () {
      final controller = EntryFormController(ledger: buildLedger());

      controller.applyScanResult(
        name: 'Cafe Luna',
        amount: dec('12.50'),
        date: DateTime.utc(2026, 3, 4),
      );

      expect(controller.nameController.text, 'Cafe Luna');
      expect(controller.amountController.text, '12.50');
      expect(controller.date, DateTime.utc(2026, 3, 4));

      controller.dispose();
    });

    test('a null name or amount leaves that field as it was', () {
      final controller = EntryFormController(ledger: buildLedger());
      controller.nameController.text = 'Typed already';

      controller.applyScanResult(date: DateTime.utc(2026, 3, 4));

      expect(controller.nameController.text, 'Typed already');
      expect(controller.amountController.text, '');
      expect(controller.date, DateTime.utc(2026, 3, 4));

      controller.dispose();
    });

    test('fields stay editable after a scan result is applied', () {
      final controller = EntryFormController(ledger: buildLedger());

      controller.applyScanResult(
        name: 'Cafe Luna',
        date: DateTime.utc(2026, 3, 4),
      );
      controller.nameController.text = 'Corrected';

      expect(controller.nameController.text, 'Corrected');

      controller.dispose();
    });
  });

  group('editing mode is unaffected by initial* params', () {
    test('an existing entry ignores initial* params entirely', () {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        date: DateTime.utc(2020, 1, 1),
      );
      final controller = EntryFormController(
        ledger: buildLedger(entries: {entry.id: entry}),
        entry: entry,
        initialName: 'Should be ignored',
        initialAmount: dec('999'),
        initialDate: DateTime.utc(2026, 3, 4),
      );

      expect(controller.nameController.text, 'Coffee run');
      expect(controller.amountController.text, '5.00');
      expect(controller.date, DateTime.utc(2020, 1, 1));

      controller.dispose();
    });
  });
}
