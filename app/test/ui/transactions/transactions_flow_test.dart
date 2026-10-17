import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/add_sheet_dismiss.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  final today = DateTime.now();
  DateTime day(int d) => DateTime.utc(today.year, today.month, d);

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final coffee = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Coffee',
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {checking.id: MoneySource.account(checking)},
        categories: {coffee.id: coffee},
        entries: entries,
      ),
    );
  }

  Future<void> pumpFlow(
    WidgetTester tester, {
    required Ledger ledger,
    TransactionsScope? initialScope,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          scanStripEnabledProvider.overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => unawaited(
                      openNewEntry(
                        context: context,
                        ref: ref,
                        sourceId: initialScope?.scopeIDs.firstOrNull,
                      ),
                    ),
                    child: const Text('Open Add'),
                  ),
                  Expanded(child: TransactionsFlow(initialScope: initialScope)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the add action opens a new, editable entry form', (
    tester,
  ) async {
    await pumpFlow(tester, ledger: buildLedger());

    await tester.tap(find.text('Open Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add entry'), findsOneWidget);
    expect(find.text('Save entry'), findsOneWidget);

    await dismissAddSheet(tester);
    await tester.pumpAndSettle();
    expect(find.text('Add entry'), findsNothing);
  });

  testWidgets('tapping a row opens the entry form for it, read-only', (
    tester,
  ) async {
    final entry = Entry(
      amount: dec('-5'),
      name: 'Coffee run',
      sourceID: checking.id,
      date: day(1),
    );
    final ledger = buildLedger(entries: {entry.id: entry});

    await pumpFlow(tester, ledger: ledger);

    await tester.tap(find.text('Coffee run'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee run'), findsWidgets);
    expect(find.text('Save entry'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
  });

  Future<void> scrollToFormRow(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('picking an account applies it to the open form', (tester) async {
    await pumpFlow(tester, ledger: buildLedger());

    await tester.tap(find.text('Open Add'));
    await tester.pumpAndSettle();

    await scrollToFormRow(tester, 'Account');
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();

    expect(find.text('Checking'), findsOneWidget);

    await dismissAddSheet(tester);
    await tester.pumpAndSettle();
  });

  testWidgets('picking a category applies it to the open form', (tester) async {
    await pumpFlow(tester, ledger: buildLedger());

    await tester.tap(find.text('Open Add'));
    await tester.pumpAndSettle();

    await scrollToFormRow(tester, 'Category');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsOneWidget);

    await dismissAddSheet(tester);
    await tester.pumpAndSettle();
  });

  testWidgets('a new entry saved through the flow lands in the ledger', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpFlow(tester, ledger: ledger);

    await tester.tap(find.text('Open Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '12.50');
    await tester.enterText(find.byType(TextField).at(1), 'New expense');
    await tester.pumpAndSettle();

    await scrollToFormRow(tester, 'Account');
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Checking'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(ledger.state.entries.length, 1);
    final added = ledger.state.entries.values.first;
    expect(added.name, 'New expense');
    expect(added.amount, dec('-12.50'));
    expect(find.text('Add entry'), findsNothing);
  });

  group('scoped flow', () {
    testWidgets('a new entry opened with a scope prefills its account', (
      tester,
    ) async {
      final scope = TransactionsScope(
        title: 'Checking',
        scopeIDs: {checking.id},
      );
      await pumpFlow(tester, ledger: buildLedger(), initialScope: scope);

      await tester.tap(find.text('Open Add'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.text('Add entry')),
      );
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        checking.id,
      );
      expect(find.text('Checking'), findsWidgets);

      await dismissAddSheet(tester);
      await tester.pumpAndSettle();
    });
  });

  testWidgets(
    'PopScope refuses to let the flow itself be popped, so back-gesture '
    'handling stays with the flow rather than the host route',
    (tester) async {
      await pumpFlow(tester, ledger: buildLedger());

      final popScope =
          find
                  .byWidgetPredicate((widget) => widget is PopScope)
                  .evaluate()
                  .single
                  .widget
              as PopScope;

      expect(popScope.canPop, isFalse);
    },
  );
}
