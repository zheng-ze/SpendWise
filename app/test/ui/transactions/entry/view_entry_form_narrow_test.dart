import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';

import '../../../support/ui_test_timeout.dart';

const narrowContentWidth = 202.0;
const windowHeight = 480.0;
const largeTextScale = 1.5;
const normalTextScale = 1.0;
const longAccountName = 'Household joint savings and everyday checking';
const longCategoryName = 'Groceries and household supplies for the family';
const longEntryName = 'Weekly shop at the corner market with the family';

final checking = Account(
  id: 'a0000000-0000-0000-0000-000000000001',
  name: longAccountName,
  type: AccountType.checking,
);
final groceries = TransactionCategory(
  id: 'c0000000-0000-0000-0000-000000000001',
  name: longCategoryName,
  kind: CategoryKind.expense,
  colorHex: '#FF0000',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'local_grocery_store',
);
final entry = Entry(
  amount: Decimal.parse('-12.50'),
  name: longEntryName,
  sourceID: checking.id,
  categoryID: groceries.id,
);

Future<void> pumpViewEntry(WidgetTester tester, double textScale) async {
  final ledger = Ledger(
    state: LedgerState(
      moneySources: {checking.id: MoneySource.account(checking)},
      categories: {groceries.id: groceries},
      entries: {entry.id: entry},
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: narrowContentWidth,
              height: windowHeight,
              child: EntryForm(entryId: entry.id),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [normalTextScale, largeTextScale]) {
    testWidgets('the read-only entry view lays out at ${scale}x text', (
      tester,
    ) async {
      await pumpViewEntry(tester, scale);

      expect(tester.takeException(), isNull);
      expect(find.text('Edit'), findsOneWidget);
    }, timeout: uiTestTimeout);
  }
}
