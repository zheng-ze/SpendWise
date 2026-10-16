import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

const narrowContentWidth = 202.0;
const largeTextScale = 1.5;
const checkingId = 'a0000000-0000-0000-0000-000000000001';
const groceriesId = 'c0000000-0000-0000-0000-000000000001';
const longAccountName = 'Household joint savings and everyday checking';
const longCategoryName = 'Groceries and household supplies for the family';

class _FakeEntryFormViewModel implements EntryFormViewModel {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Ledger buildLedger() {
  final checking = Account(
    id: checkingId,
    name: longAccountName,
    type: AccountType.checking,
  );
  final groceries = TransactionCategory(
    id: groceriesId,
    name: longCategoryName,
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_grocery_store',
  );
  return Ledger(
    state: LedgerState(
      moneySources: {checking.id: MoneySource.account(checking)},
      categories: {groceries.id: groceries},
    ),
  );
}

EntryFormViewState buildState({
  required EntryFormMode mode,
  RecurrenceFrequency? recurrence,
  bool hasEndDate = false,
}) {
  return EntryFormViewState(
    mode: mode,
    kind: EntryFormKind.expense,
    amountText: '12.50',
    nameText: 'Weekly shop',
    date: DateTime.utc(2026, 10, 16),
    sourceId: checkingId,
    destinationId: null,
    categoryId: groceriesId,
    includeInAnalysis: true,
    recurrence: recurrence,
    hasEndDate: hasEndDate,
    endDate: DateTime.utc(2027, 1, 16),
    isSystemEntry: false,
    entryId: mode == EntryFormMode.newEntry ? null : 'entry-1',
  );
}

Future<void> pumpEntryFieldsAtNarrowWidth(
  WidgetTester tester, {
  required EntryFormViewState state,
  required bool readOnly,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ledgerProvider.overrideWithValue(buildLedger())],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: const TextScaler.linear(largeTextScale),
                ),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: narrowContentWidth,
                    child: EntryFields(
                      viewModel: _FakeEntryFormViewModel(),
                      state: state,
                      readOnly: readOnly,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('EntryFields at 202 dp and 1.5x text', () {
    testWidgets('the add rows with recurrence and an end date lay out', (
      tester,
    ) async {
      await pumpEntryFieldsAtNarrowWidth(
        tester,
        state: buildState(
          mode: EntryFormMode.newEntry,
          recurrence: RecurrenceFrequency.monthly,
          hasEndDate: true,
        ),
        readOnly: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('End date'), findsOneWidget);
      expect(find.text('Include in Analysis'), findsOneWidget);
    });

    testWidgets('the edit rows lay out with long account and category names', (
      tester,
    ) async {
      await pumpEntryFieldsAtNarrowWidth(
        tester,
        state: buildState(mode: EntryFormMode.editing),
        readOnly: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
    });

    testWidgets('the read-only view rows lay out and keep their values', (
      tester,
    ) async {
      await pumpEntryFieldsAtNarrowWidth(
        tester,
        state: buildState(mode: EntryFormMode.viewing),
        readOnly: true,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Include in Analysis'), findsOneWidget);
    });
  });
}
