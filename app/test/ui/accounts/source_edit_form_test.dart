import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/source_edit_form.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Future<void> pumpForm(WidgetTester tester, Ledger ledger, String holderID) {
    return tester.pumpWidget(
      MaterialApp(
        home: SourceEditForm(ledger: ledger, holderID: holderID),
      ),
    );
  }

  testWidgets('saving with an unchanged balance posts no entry', (
    tester,
  ) async {
    final account = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Wallet',
      type: AccountType.cash,
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        entries: {
          'e0000000-0000-0000-0000-000000000001': Entry(
            id: 'e0000000-0000-0000-0000-000000000001',
            amount: dec('100'),
            name: 'Opening balance',
            sourceID: account.id,
            includeInAnalysis: false,
          ),
        },
      ),
    );

    await pumpForm(tester, ledger, account.id);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.entries, hasLength(1));
  });

  testWidgets('raising the balance posts one adjustment entry excluded '
      'from analysis', (tester) async {
    final account = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Wallet',
      type: AccountType.cash,
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        entries: {
          'e0000000-0000-0000-0000-000000000001': Entry(
            id: 'e0000000-0000-0000-0000-000000000001',
            amount: dec('100'),
            name: 'Opening balance',
            sourceID: account.id,
            includeInAnalysis: false,
          ),
        },
      ),
    );

    await pumpForm(tester, ledger, account.id);
    await tester.enterText(find.byType(TextField).at(1), '150.00');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.entries, hasLength(2));
    final posted = ledger.state.entries.values.firstWhere(
      (e) => e.id != 'e0000000-0000-0000-0000-000000000001',
    );
    expect(posted.amount, dec('50'));
    expect(posted.includeInAnalysis, isFalse);
    expect(posted.sourceID, account.id);
  });

  testWidgets('lowering the balance posts a negative adjustment entry', (
    tester,
  ) async {
    final account = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Wallet',
      type: AccountType.cash,
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        entries: {
          'e0000000-0000-0000-0000-000000000001': Entry(
            id: 'e0000000-0000-0000-0000-000000000001',
            amount: dec('100'),
            name: 'Opening balance',
            sourceID: account.id,
            includeInAnalysis: false,
          ),
        },
      ),
    );

    await pumpForm(tester, ledger, account.id);
    await tester.enterText(find.byType(TextField).at(1), '40.00');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.entries, hasLength(2));
    final posted = ledger.state.entries.values.firstWhere(
      (e) => e.id != 'e0000000-0000-0000-0000-000000000001',
    );
    expect(posted.amount, dec('-60'));
    expect(posted.includeInAnalysis, isFalse);
  });

  testWidgets('an empty balance field counts as zero and needs no entry', (
    tester,
  ) async {
    final account = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Wallet',
      type: AccountType.cash,
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );

    await pumpForm(tester, ledger, account.id);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(ledger.state.entries, isEmpty);
  });

  testWidgets('net worth toggle is hidden for a pocket', (tester) async {
    final account = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Wallet',
      type: AccountType.cash,
    );
    final pocket = SubPocket(
      id: 'p0000000-0000-0000-0000-000000000001',
      name: 'Vacation',
    );
    final linkedAccount = account.addSubPocket(pocket.id);
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {
          linkedAccount.id: MoneySource.account(linkedAccount),
          pocket.id: MoneySource.pocket(pocket),
        },
      ),
    );

    await pumpForm(tester, ledger, pocket.id);

    expect(find.text('Include in net worth'), findsNothing);
    // Cash cannot treat incoming transfers as expenses, and a pocket has no
    // type of its own, so it follows its parent account's eligibility.
    expect(find.text('Transfers in count as expenses'), findsNothing);
    expect(find.text('Type'), findsNothing);
  });

  testWidgets('transfer toggle shows for a pocket whose parent is eligible', (
    tester,
  ) async {
    final account = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Nest egg',
      type: AccountType.savings,
    );
    final pocket = SubPocket(
      id: 'p0000000-0000-0000-0000-000000000001',
      name: 'Vacation',
    );
    final linkedAccount = account.addSubPocket(pocket.id);
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {
          linkedAccount.id: MoneySource.account(linkedAccount),
          pocket.id: MoneySource.pocket(pocket),
        },
      ),
    );

    await pumpForm(tester, ledger, pocket.id);

    expect(find.text('Transfers in count as expenses'), findsOneWidget);
  });

  testWidgets('switching an account to an ineligible type hides and resets the '
      'transfer toggle', (tester) async {
    final account = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Nest egg',
      type: AccountType.savings,
      incomingTransfersAsExpenses: true,
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );

    await pumpForm(tester, ledger, account.id);
    expect(find.text('Transfers in count as expenses'), findsOneWidget);

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();

    expect(find.text('Transfers in count as expenses'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = ledger.state.moneySources[account.id]!.asAccount!;
    expect(stored.incomingTransfersAsExpenses, isFalse);
  });
}
