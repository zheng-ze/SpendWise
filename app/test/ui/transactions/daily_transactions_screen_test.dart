import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/semantics_test_support.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  // The screen defaults to the current month, so the fixture entries must
  // land inside it rather than a fixed calendar day.
  final today = DateTime.now();
  DateTime day(int d) => DateTime.utc(today.year, today.month, d);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  testWidgets(
    'swiping a row deletes the entry it displays, not another row at the '
    'same position',
    (tester) async {
      // Same day, same list position after the day's newest-first sort is
      // what a zip-by-index bug would confuse: the second entry to be
      // entered lands first in the list and is the one swiped.
      final keepEntry = Entry(
        amount: dec('-5'),
        name: 'keep me',
        sourceID: account.id,
        date: day(1),
      );
      final deleteEntry = Entry(
        amount: dec('-9'),
        name: 'delete me',
        sourceID: account.id,
        date: day(1),
      );

      final ledger = Ledger(
        state: LedgerState(
          moneySources: {account.id: MoneySource.account(account)},
          entries: {keepEntry.id: keepEntry, deleteEntry.id: deleteEntry},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [ledgerProvider.overrideWithValue(ledger)],
          child: const MaterialApp(home: TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('delete me'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(ledger.state.entries.containsKey(deleteEntry.id), isFalse);
      expect(ledger.state.entries.containsKey(keepEntry.id), isTrue);
    },
  );

  testWidgets(
    'the delete custom semantic action opens the same confirm dialog as '
    'the swipe and deletes only that row',
    (tester) async {
      final handle = tester.ensureSemantics();
      final keepEntry = Entry(
        amount: dec('-5'),
        name: 'keep me',
        sourceID: account.id,
        date: day(1),
      );
      final deleteEntry = Entry(
        amount: dec('-9'),
        name: 'delete me',
        sourceID: account.id,
        date: day(1),
      );

      final ledger = Ledger(
        state: LedgerState(
          moneySources: {account.id: MoneySource.account(account)},
          entries: {keepEntry.id: keepEntry, deleteEntry.id: deleteEntry},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [ledgerProvider.overrideWithValue(ledger)],
          child: const MaterialApp(home: TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await performCustomSemanticsAction(
        tester,
        of: find.text('delete me'),
        label: 'Delete Uncategorized',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(ledger.state.entries.containsKey(deleteEntry.id), isFalse);
      expect(ledger.state.entries.containsKey(keepEntry.id), isTrue);
      handle.dispose();
    },
  );

  testWidgets(
    'a system entry row can be swiped away and deletes like any other row',
    (tester) async {
      final systemEntry = Entry(
        amount: dec('250'),
        name: 'Opening balance',
        sourceID: account.id,
        date: day(1),
        includeInAnalysis: false,
        systemKind: SystemEntryKind.openingBalance,
      );

      final ledger = Ledger(
        state: LedgerState(
          moneySources: {account.id: MoneySource.account(account)},
          entries: {systemEntry.id: systemEntry},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [ledgerProvider.overrideWithValue(ledger)],
          child: const MaterialApp(home: TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Dismissible), findsOneWidget);

      await tester.drag(find.text('Opening balance'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(ledger.state.entries.containsKey(systemEntry.id), isFalse);
    },
  );

  testWidgets('shows the scope title and an edit-source action when scoped', (
    tester,
  ) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
    final scope = TransactionsScope(title: 'Checking', scopeIDs: {account.id});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: MaterialApp(home: TransactionsScreen(scope: scope)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checking'), findsOneWidget);

    // "Edit Checking" is a secondary FAB action, shown only once the FAB
    // expands.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Edit Checking'), findsOneWidget);
  });

  testWidgets(
    'shows the default title and no edit-source action when unscoped',
    (tester) async {
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {account.id: MoneySource.account(account)},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [ledgerProvider.overrideWithValue(ledger)],
          child: const MaterialApp(home: TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    },
  );
}
