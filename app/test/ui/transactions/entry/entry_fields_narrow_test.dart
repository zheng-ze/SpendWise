import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

import '../../../support/ui_test_timeout.dart';

const narrowContentWidth = 202.0;
const normalContentWidth = 400.0;
const largeTextScale = 1.5;
const normalTextScale = 1.0;
const checkingId = 'a0000000-0000-0000-0000-000000000001';
const savingsId = 'a0000000-0000-0000-0000-000000000002';
const groceriesId = 'c0000000-0000-0000-0000-000000000001';
const longAccountName = 'Household joint savings and everyday checking';
const longSavingsName = 'Emergency fund for the whole family household';
const longCategoryName = 'Groceries and household supplies for the family';
const includeInAnalysisLabel = 'Include in Analysis';
final entryDate = DateTime.utc(2026, 10, 16);

class _FakeEntryFormViewModel implements EntryFormViewModel {
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Ledger buildLedger() {
  final checking = Account(
    id: checkingId,
    name: longAccountName,
    type: AccountType.checking,
  );
  final savings = Account(
    id: savingsId,
    name: longSavingsName,
    type: AccountType.savings,
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
      moneySources: {
        checking.id: MoneySource.account(checking),
        savings.id: MoneySource.account(savings),
      },
      categories: {groceries.id: groceries},
    ),
  );
}

EntryFormViewState buildState({
  required EntryFormMode mode,
  EntryFormKind kind = EntryFormKind.expense,
  String? destinationId,
}) {
  return EntryFormViewState(
    mode: mode,
    kind: kind,
    amountText: '12.50',
    nameText: 'Weekly shop',
    date: entryDate,
    sourceId: checkingId,
    destinationId: destinationId,
    categoryId: groceriesId,
    includeInAnalysis: true,
    recurrence: null,
    hasEndDate: false,
    endDate: DateTime.utc(2027, 1, 16),
    isSystemEntry: false,
    entryId: 'entry-1',
  );
}

TransitionBuilder textScaled(double scale) {
  return (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child ?? const SizedBox.shrink(),
  );
}

Widget narrowBody({
  required EntryFormViewState state,
  required bool readOnly,
  required double width,
}) {
  final fields = EntryFields(
    viewModel: _FakeEntryFormViewModel(),
    state: state,
    readOnly: readOnly,
  );
  return SingleChildScrollView(
    child: SizedBox(width: width, child: fields),
  );
}

Future<void> pumpFields(
  WidgetTester tester, {
  required EntryFormViewState state,
  required bool readOnly,
  double width = narrowContentWidth,
  double textScale = largeTextScale,
}) async {
  final body = narrowBody(state: state, readOnly: readOnly, width: width);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ledgerProvider.overrideWithValue(buildLedger())],
      child: MaterialApp(
        builder: textScaled(textScale),
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('EntryFields at 202 dp and 1.5x text', () {
    testWidgets('the edit rows show the long account and category names', (
      tester,
    ) async {
      await pumpFields(
        tester,
        state: buildState(mode: EntryFormMode.editing),
        readOnly: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text(longAccountName), findsOneWidget);
      expect(find.text(longCategoryName), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('the read-only view rows lay out and keep their values', (
      tester,
    ) async {
      await pumpFields(
        tester,
        state: buildState(mode: EntryFormMode.viewing),
        readOnly: true,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text(longCategoryName), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('the transfer rows show the long From and To names', (
      tester,
    ) async {
      await pumpFields(
        tester,
        state: buildState(
          mode: EntryFormMode.editing,
          kind: EntryFormKind.transfer,
          destinationId: savingsId,
        ),
        readOnly: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text(longAccountName), findsOneWidget);
      expect(find.text(longSavingsName), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('the analysis switch label stays inside the content width', (
      tester,
    ) async {
      await pumpFields(
        tester,
        state: buildState(mode: EntryFormMode.editing),
        readOnly: false,
      );

      expect(tester.takeException(), isNull);
      final labelRect = tester.getRect(find.text(includeInAnalysisLabel));
      expect(labelRect.right, lessThanOrEqualTo(narrowContentWidth));
    }, timeout: uiTestTimeout);

    testWidgets('a value that wraps under its title stays right-aligned', (
      tester,
    ) async {
      await pumpFields(
        tester,
        state: buildState(mode: EntryFormMode.editing),
        readOnly: false,
      );

      final tileRect = tester.getRect(find.widgetWithText(ListTile, 'Account'));
      final valueRect = tester.getRect(find.text(longAccountName));
      expect(valueRect.right, closeTo(tileRect.right, 0.5));
    }, timeout: uiTestTimeout);
  });

  group('EntryFields value style at normal width', () {
    testWidgets('the Date value keeps the list tile trailing style', (
      tester,
    ) async {
      await pumpFields(
        tester,
        state: buildState(mode: EntryFormMode.editing),
        readOnly: false,
        width: normalContentWidth,
        textScale: normalTextScale,
      );

      final dateText = formatEntryDate(entryDate);
      final valueWidget = tester.widget<Text>(find.text(dateText));
      final theme = Theme.of(tester.element(find.text(dateText)));
      expect(valueWidget.style?.fontSize, theme.textTheme.labelSmall?.fontSize);
      expect(valueWidget.style?.color, theme.colorScheme.onSurfaceVariant);
    }, timeout: uiTestTimeout);
  });
}
