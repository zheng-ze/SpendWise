import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry_form.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final checking = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
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
  final salary = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Salary',
    kind: CategoryKind.income,
    colorHex: '#00FF00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'work',
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {
          checking.id: MoneySource.account(checking),
          savings.id: MoneySource.account(savings),
        },
        categories: {coffee.id: coffee, salary.id: salary},
        entries: entries,
      ),
    );
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    required Ledger ledger,
    Entry? entry,
    String? sourceScope,
  }) async {
    // The real EntryForm always renders inside a modal bottom sheet, which
    // sits over the host app's own Scaffold/Material. Without one here, Text
    // falls back to the debug banner's oversized style and rows overflow.
    await tester.pumpWidget(
      ProviderScope(
        // The new-entry form's scan strip reads this setting; fixed here so
        // its default doesn't depend on real (unmocked) SharedPreferences.
        overrides: [scanStripEnabledProvider.overrideWith((ref) async => true)],
        child: MaterialApp(
          home: Scaffold(
            body: EntryForm(
              ledger: ledger,
              entry: entry,
              sourceScope: sourceScope,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('modes', () {
    testWidgets('a new entry opens directly editable with a Save action', (
      tester,
    ) async {
      await pumpForm(tester, ledger: buildLedger());

      expect(find.text('New Entry'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('an existing entry opens read-only with an Edit control', (
      tester,
    ) async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      await pumpForm(
        tester,
        ledger: buildLedger(entries: {entry.id: entry}),
        entry: entry,
      );

      expect(find.text('Coffee run'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets(
      'the read-only view has no live input controls, only plain rows',
      (tester) async {
        final entry = Entry(
          amount: dec('-5'),
          name: 'Coffee run',
          sourceID: checking.id,
          categoryID: coffee.id,
        );
        await pumpForm(
          tester,
          ledger: buildLedger(entries: {entry.id: entry}),
          entry: entry,
        );

        expect(find.byType(SegmentedButton<EntryFormKind>), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(SwitchListTile), findsNothing);
      },
    );

    testWidgets('tapping Edit switches to edit mode with a Save action', (
      tester,
    ) async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      await pumpForm(
        tester,
        ledger: buildLedger(entries: {entry.id: entry}),
        entry: entry,
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Entry'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('while viewing, Delete Entry is unreachable', (tester) async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      await pumpForm(
        tester,
        ledger: buildLedger(entries: {entry.id: entry}),
        entry: entry,
      );

      expect(find.text('Delete Entry'), findsNothing);
    });

    testWidgets('tapping Edit reveals live fields not shown while viewing', (
      tester,
    ) async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      await pumpForm(
        tester,
        ledger: buildLedger(entries: {entry.id: entry}),
        entry: entry,
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Delete Entry'), findsOneWidget);
    });
  });

  group('cancel from edit reverts', () {
    testWidgets('reverts the name field and returns to read-only, sheet open', (
      tester,
    ) async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      final ledger = buildLedger(entries: {entry.id: entry});
      await pumpForm(tester, ledger: ledger, entry: entry);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'Changed name');
      await tester.pumpAndSettle();

      // No Cancel button in the new design; a barrier tap or back gesture
      // reaches the same PopScope revert. Trigger it directly through the
      // navigator, since this harness hosts EntryForm without a real modal
      // bottom sheet to tap outside of.
      await Navigator.of(tester.element(find.byType(EntryForm))).maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Coffee run'), findsOneWidget);
      expect(find.text('Changed name'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
      expect(ledger.state.entries[entry.id]!.name, 'Coffee run');
    });
  });

  group('kind change clears category', () {
    testWidgets('switching from expense to income clears the selection', (
      tester,
    ) async {
      final ledger = buildLedger();
      await pumpForm(tester, ledger: ledger);

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsNothing);
      expect(find.text('None'), findsOneWidget);
    });
  });

  group('save paths', () {
    testWidgets(
      'editing an existing entry updates it and returns to read-only',
      (tester) async {
        final entry = Entry(
          amount: dec('-5'),
          name: 'Coffee run',
          sourceID: checking.id,
          categoryID: coffee.id,
        );
        final ledger = buildLedger(entries: {entry.id: entry});
        await pumpForm(tester, ledger: ledger, entry: entry);

        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(1), 'Updated name');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(ledger.state.entries[entry.id]!.name, 'Updated name');
        expect(find.text('Updated name'), findsOneWidget);
        expect(find.text('Save'), findsNothing);
      },
    );

    testWidgets('a new entry without recurrence adds it and dismisses', (
      tester,
    ) async {
      final ledger = buildLedger();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scanStripEnabledProvider.overrideWith((ref) async => true),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(body: EntryForm(ledger: ledger)),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '12.50');
      await tester.enterText(find.byType(TextField).at(1), 'New expense');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(ledger.state.entries.length, 1);
      final added = ledger.state.entries.values.first;
      expect(added.name, 'New expense');
      expect(added.amount, dec('-12.50'));
    });

    testWidgets(
      'a new entry with recurrence creates a plan and resolves the anchor day',
      (tester) async {
        final ledger = buildLedger();
        await pumpForm(tester, ledger: ledger);

        await tester.enterText(find.byType(TextField).at(0), '20');
        await tester.enterText(find.byType(TextField).at(1), 'Rent');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Checking'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.repeat));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Monthly'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(ledger.state.plans.length, 1);
        expect(ledger.state.entries.length, 1);
        final added = ledger.state.entries.values.first;
        expect(added.name, 'Rent');
      },
    );
  });

  group('delete', () {
    testWidgets('deletes and dismisses without a confirmation', (tester) async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      final ledger = buildLedger(entries: {entry.id: entry});

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: EntryForm(ledger: ledger, entry: entry),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Entry'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this transaction?'), findsNothing);
      expect(ledger.state.entries.containsKey(entry.id), isFalse);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('system entries', () {
    testWidgets(
      'an opening balance entry opens read-only with an Edit control',
      (tester) async {
        final entry = Entry(
          amount: dec('250'),
          name: 'Opening balance',
          sourceID: checking.id,
          includeInAnalysis: false,
          systemKind: SystemEntryKind.openingBalance,
        );
        await pumpForm(
          tester,
          ledger: buildLedger(entries: {entry.id: entry}),
          entry: entry,
        );

        expect(find.text('Opening balance'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
      },
    );

    testWidgets(
      'editing an opening balance entry locks name, category and include '
      'in analysis, but leaves amount and delete usable',
      (tester) async {
        final entry = Entry(
          amount: dec('250'),
          name: 'Opening balance',
          sourceID: checking.id,
          includeInAnalysis: false,
          systemKind: SystemEntryKind.openingBalance,
        );
        final ledger = buildLedger(entries: {entry.id: entry});
        await pumpForm(tester, ledger: ledger, entry: entry);

        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Entry'), findsOneWidget);

        final nameIgnore = tester.firstWidget<IgnorePointer>(
          find.ancestor(
            of: find.byType(TextField).at(1),
            matching: find.byType(IgnorePointer),
          ),
        );
        expect(nameIgnore.ignoring, isTrue);

        final categoryTile = tester.widget<ListTile>(
          find.widgetWithText(ListTile, 'Category'),
        );
        expect(categoryTile.onTap, isNull);

        final analysisSwitch = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, 'Include in Analysis'),
        );
        expect(analysisSwitch.onChanged, isNull);

        final amountIgnore = tester.firstWidget<IgnorePointer>(
          find.ancestor(
            of: find.byType(TextField).first,
            matching: find.byType(IgnorePointer),
          ),
        );
        expect(amountIgnore.ignoring, isFalse);

        expect(find.text('Delete Entry'), findsOneWidget);

        await tester.tap(find.text('Delete Entry'));
        await tester.pumpAndSettle();

        expect(ledger.state.entries.containsKey(entry.id), isFalse);
      },
    );

    testWidgets('a balance adjustment entry opens read-only the same way', (
      tester,
    ) async {
      final entry = Entry(
        amount: dec('-10'),
        name: 'Balance adjustment',
        sourceID: checking.id,
        includeInAnalysis: false,
        systemKind: SystemEntryKind.balanceAdjustment,
      );
      await pumpForm(
        tester,
        ledger: buildLedger(entries: {entry.id: entry}),
        entry: entry,
      );

      expect(find.text('Balance adjustment'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('a normal entry is unaffected and still offers Edit', (
      tester,
    ) async {
      final entry = Entry(
        amount: dec('-5'),
        name: 'Coffee run',
        sourceID: checking.id,
        categoryID: coffee.id,
      );
      await pumpForm(
        tester,
        ledger: buildLedger(entries: {entry.id: entry}),
        entry: entry,
      );

      expect(find.text('Edit'), findsOneWidget);
    });
  });

  group('prefill from scope', () {
    testWidgets('a new entry opened with a source scope prefills its account', (
      tester,
    ) async {
      final ledger = buildLedger();
      await pumpForm(tester, ledger: ledger, sourceScope: checking.id);

      expect(find.text('Checking'), findsOneWidget);
    });
  });

  group('picker mounted guard', () {
    testWidgets(
      'resolving the category picker after the form is popped does not throw',
      (tester) async {
        final ledger = buildLedger();
        // Captured so it can be removed directly, since the sheet route
        // sits above it and pop() would dismiss the sheet instead.
        final formRoute = MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: EntryForm(ledger: ledger)),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scanStripEnabledProvider.overrideWith((ref) async => true),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(formRoute),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Category'));
        await tester.pumpAndSettle();

        // Removes the form's own route out from under the still-open sheet,
        // disposing EntryForm's State while the picker future is pending.
        final rootNavigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        rootNavigator.removeRoute(formRoute);
        await tester.pump();

        await tester.tap(find.text('Coffee'));

        // A setState on the disposed EntryForm would throw here.
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
