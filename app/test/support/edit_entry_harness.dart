import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import 'pump_app.dart';

final editChecking = Account(name: 'Checking', type: AccountType.checking);

final editGroceries = TransactionCategory(
  name: 'Groceries',
  kind: CategoryKind.expense,
  colorHex: '#FF0000',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'local_cafe',
);

final editCoffee = TransactionCategory(
  name: 'Coffee',
  kind: CategoryKind.expense,
  colorHex: '#00FF00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'local_cafe',
);

Entry editableEntry() => Entry(
  amount: Decimal.parse('-5'),
  name: 'Coffee run',
  sourceID: editChecking.id,
  categoryID: editGroceries.id,
);

Entry openingBalanceEntry() => Entry(
  amount: Decimal.parse('250'),
  name: 'Opening balance',
  sourceID: editChecking.id,
  includeInAnalysis: false,
  systemKind: SystemEntryKind.openingBalance,
);

Ledger editLedger(List<Entry> entries) => Ledger(
  state: LedgerState(
    moneySources: {editChecking.id: MoneySource.account(editChecking)},
    categories: {editGroceries.id: editGroceries, editCoffee.id: editCoffee},
    entries: {for (final entry in entries) entry.id: entry},
  ),
);

class EditHost {
  late BuildContext context;
  late WidgetRef ref;

  ProviderContainer get container => ProviderScope.containerOf(context);
}

class _CapturingHost extends ConsumerWidget {
  const _CapturingHost(this.host);

  final EditHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    host.context = context;
    host.ref = ref;
    return const Scaffold(body: SizedBox.expand());
  }
}

Future<EditHost> pumpEditHost(WidgetTester tester, Ledger ledger) async {
  final host = EditHost();
  await pumpApp(tester, _CapturingHost(host), ledger: ledger);
  addTearDown(() => closeAllSheets(tester));
  return host;
}

Future<void> closeAllSheets(WidgetTester tester) async {
  final sheets = find.byType(AppSheet, skipOffstage: false);
  while (sheets.evaluate().isNotEmpty) {
    Navigator.of(tester.element(sheets.last), rootNavigator: true).pop();
    await tester.pumpAndSettle();
  }
}
