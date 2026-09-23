import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Main Checking',
    type: AccountType.checking,
    subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
  );
  final rentPocket = SubPocket(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Rent',
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'Piggy Bank',
    type: AccountType.savings,
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          rentPocket.id: MoneySource.pocket(rentPocket),
          savings.id: MoneySource.account(savings),
        },
        entries: entries,
      ),
    );
  }

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester,
    Ledger ledger,
  ) async {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountsScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'expansion is single-open, opening a second collapses the first',
    (tester) async {
      final ledger = buildLedger();
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Excluding subpockets'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsNothing);
    },
  );

  testWidgets('tapping the account row body emits AccountOpened scoped to '
      'the account plus pockets', (tester) async {
    final ledger = buildLedger();
    final container = await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Main Checking'));
    await tester.pump();

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<AccountOpened>());
    final opened = step as AccountOpened;
    expect(opened.title, 'Main Checking');
    expect(opened.scopeIDs, {checking.id, rentPocket.id});
  });

  testWidgets('the excluding-subpockets row emits AccountAloneOpened', (
    tester,
  ) async {
    final ledger = buildLedger();
    final container = await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Excluding subpockets'));
    await tester.pump();

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<AccountAloneOpened>());
    final opened = step as AccountAloneOpened;
    expect(opened.title, 'Main Checking');
    expect(opened.scopeIDs, {checking.id});
  });

  testWidgets('a pocket row emits PocketOpened scoped to the pocket alone', (
    tester,
  ) async {
    final ledger = buildLedger();
    final container = await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rent'));
    await tester.pump();

    final step = container.read(accountsViewModelProvider).value?.step;
    expect(step, isA<PocketOpened>());
    final opened = step as PocketOpened;
    expect(opened.title, 'Rent');
    expect(opened.scopeIDs, {rentPocket.id});
  });

  testWidgets('the delete confirmation names the account', (tester) async {
    final entry = Entry(amount: dec('10'), name: 'x', sourceID: savings.id);
    final ledger = buildLedger(entries: {entry.id: entry});
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Piggy Bank'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete Piggy Bank?'), findsOneWidget);
  });

  testWidgets('deleting an expanded account collapses it', (tester) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);

    await tester.drag(find.text('Main Checking'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.moneySources[checking.id]!.lifecycle,
      LifecycleState.archived,
    );
    expect(find.text('Rent'), findsNothing);
    expect(find.text('Excluding subpockets'), findsNothing);
  });

  testWidgets('swiping an account row archives it behind a confirmation', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Piggy Bank'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.activeAccounts.map((a) => a.name),
      isNot(contains('Piggy Bank')),
    );
  });

  testWidgets('swiping a pocket row archives it behind a confirmation', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Rent'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      ledger.state.moneySources[rentPocket.id]!.lifecycle,
      LifecycleState.archived,
    );
  });
}
