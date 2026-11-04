import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

import '../../support/edit_entry_harness.dart';
import '../../support/shell_sheet_harness.dart';
import '../../support/ui_test_timeout.dart';

const _openSize = Size(960, 720);
const _desktopSize = Size(1440, 900);
const _phoneSize = Size(390, 844);
const _editTitle = 'Edit entry';
const _updateLabel = 'Update entry';
const _deleteKey = ValueKey('edit-entry-delete');
const _newAmount = '42';
const _headerAndRowDateCount = 2;

class _HistoryPane {
  _HistoryPane(this.container, this.entry);

  final ProviderContainer container;
  final Entry entry;

  Finder get pane => find.byKey(shellDetailPaneKey);
  Finder get row => find.text(entry.name);
}

Future<_HistoryPane> _pumpHistory(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
}) async {
  useShellWindow(tester, size);
  final entry = editableEntry();
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(editLedger([entry])),
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
  return _HistoryPane(container, entry);
}

Future<_HistoryPane> _pumpOpenHistory(WidgetTester tester) =>
    _pumpHistory(tester, size: _openSize, platform: TargetPlatform.android);

Future<void> _openPane(WidgetTester tester, _HistoryPane history) async {
  await tester.tap(history.row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AC1: an open-layout row tap shows Edit entry in the detail pane',
    (tester) async {
      final history = await _pumpOpenHistory(tester);

      await tester.tap(history.row);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      final inPane = find.descendant(
        of: history.pane,
        matching: find.text(_editTitle),
      );
      final subtitleAndDateRow = find.descendant(
        of: history.pane,
        matching: find.text(formatEntryDate(history.entry.date)),
      );
      expect(inPane, findsOneWidget);
      expect(subtitleAndDateRow, findsNWidgets(_headerAndRowDateCount));
      expect(find.byType(AppSheet), findsNothing);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('Close removes the pane and discards the draft', (tester) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);

    await tester.tap(find.byKey(shellDetailCloseKey));
    await tester.pumpAndSettle();

    expect(history.pane, findsNothing);
    expect(history.row, findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('Update saves the entry and clears the pane', (tester) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);
    history.container
        .read(entryFormViewModelProvider(history.entry.id).notifier)
        .setAmount(_newAmount);
    await tester.pumpAndSettle();

    await tester.tap(find.text(_updateLabel));
    await tester.pumpAndSettle();

    final saved = history.container
        .read(ledgerProvider)!
        .state
        .entries[history.entry.id]!;
    expect(saved.amount, Decimal.parse('-$_newAmount'));
    expect(history.pane, findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('Delete archives the entry, clears the pane and the row', (
    tester,
  ) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);

    await tester.tap(find.byKey(_deleteKey));
    await tester.pumpAndSettle();

    final state = history.container.read(ledgerProvider)!.state;
    expect(state.binnedEntries.containsKey(history.entry.id), isTrue);
    expect(history.pane, findsNothing);
    expect(history.row, findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('desktop layout opens the detail pane', (tester) async {
    final history = await _pumpHistory(
      tester,
      size: _desktopSize,
      platform: TargetPlatform.macOS,
    );

    await _openPane(tester, history);

    final inPane = find.descendant(
      of: history.pane,
      matching: find.text(_editTitle),
    );
    expect(inPane, findsOneWidget);
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('phone layout opens the Edit entry sheet', (tester) async {
    final history = await _pumpHistory(
      tester,
      size: _phoneSize,
      platform: TargetPlatform.android,
    );
    addTearDown(() => closeAllSheets(tester));

    await _openPane(tester, history);

    expect(history.pane, findsNothing);
    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text(_editTitle), findsOneWidget);
  }, timeout: uiTestTimeout);
}
