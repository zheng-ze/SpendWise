import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/account_form/account_form.dart';
import 'package:spendwise/ui/accounts/account_form/account_form_logic.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester, Ledger ledger) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: const MaterialApp(home: Scaffold(body: AccountForm())),
      ),
    );
    // Flushes AccountFormNotifier.build()'s Future so the form's initial
    // AsyncData state is in place before a test interacts with it.
    await tester.pump();
  }

  testWidgets('locks to account kind when no account can hold a pocket', (
    tester,
  ) async {
    final card = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Visa',
      type: AccountType.card,
      statementDay: 15,
    );
    final ledger = Ledger(
      state: LedgerState(moneySources: {card.id: MoneySource.account(card)}),
    );

    await pumpForm(tester, ledger);

    final segmented = tester.widget<SegmentedButton<AccountFormKind>>(
      find.byType(SegmentedButton<AccountFormKind>),
    );
    expect(segmented.onSelectionChanged, isNull);
    expect(segmented.selected, {AccountFormKind.account});
  });

  testWidgets('statement day field appears only for card type', (tester) async {
    final ledger = Ledger();
    await pumpForm(tester, ledger);

    expect(find.text('Statement Day'), findsNothing);

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();

    expect(find.text('Statement Day'), findsOneWidget);
  });

  testWidgets('saving an account with zero opening balance posts no entry', (
    tester,
  ) async {
    final ledger = Ledger();
    await pumpForm(tester, ledger);

    await tester.enterText(find.byType(TextField).first, 'Wallet');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.entries, isEmpty);
    expect(ledger.state.activeAccounts, hasLength(1));
    expect(ledger.state.activeAccounts.single.name, 'Wallet');
  });

  testWidgets('statement day is not persisted for a non-card account', (
    tester,
  ) async {
    final ledger = Ledger();
    await pumpForm(tester, ledger);

    await tester.enterText(find.byType(TextField).first, 'Wallet');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.activeAccounts.single.statementDay, isNull);
  });

  testWidgets('saving a card persists its statement day', (tester) async {
    final ledger = Ledger();
    await pumpForm(tester, ledger);

    await tester.enterText(find.byType(TextField).first, 'Visa');
    await tester.pump();
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statement Day'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.activeAccounts.single.statementDay, 1);
  });
}
