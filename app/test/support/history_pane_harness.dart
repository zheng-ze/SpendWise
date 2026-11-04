import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import 'edit_entry_harness.dart';
import 'shell_sheet_harness.dart';

class HistoryPane {
  HistoryPane(this.container, this.entries);

  final ProviderContainer container;
  final List<Entry> entries;

  Entry get first => entries.first;
  Entry get second => entries.last;

  Finder get pane => find.byKey(shellDetailPaneKey);

  Finder rowOf(Entry entry) => find.descendant(
    of: find.byType(TransactionsFlow),
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == entry.name,
    ),
  );

  Finder get row => rowOf(first);

  EntryFormNotifier formOf(Entry entry) =>
      container.read(entryFormViewModelProvider(entry.id).notifier);

  String amountTextOf(Entry entry) =>
      container.read(entryFormViewModelProvider(entry.id)).value!.amountText;

  String? categoryIdOf(Entry entry) =>
      container.read(entryFormViewModelProvider(entry.id)).value!.categoryId;

  WidgetRef flowRef(WidgetTester tester) =>
      tester.element(find.byType(TransactionsFlow)) as WidgetRef;

  BuildContext flowContext(WidgetTester tester) =>
      tester.element(find.byType(TransactionsFlow));
}

Entry secondEditableEntry() => Entry(
  amount: Decimal.parse('-9'),
  name: 'Lunch out',
  sourceID: editChecking.id,
  categoryID: editGroceries.id,
);

Future<HistoryPane> pumpHistoryPane(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
  List<Entry>? entries,
}) async {
  useShellWindow(tester, size);
  final seeded = entries ?? [editableEntry(), secondEditableEntry()];
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(editLedger(seeded)),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      shellPlatformProvider.overrideWithValue((
        isWeb: false,
        targetPlatform: platform,
      )),
    ],
  );
  addTearDown(container.dispose);
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.history;
  await pumpShellApp(
    tester,
    container,
    bodies: {ShellDestination.history: (_) => const TransactionsFlow()},
  );
  return HistoryPane(container, seeded);
}

Future<void> tapHistoryRow(
  WidgetTester tester,
  HistoryPane history,
  Entry entry,
) async {
  await tester.tap(history.rowOf(entry));
  await tester.pumpAndSettle();
}

Future<void> resizeShellWindow(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}
