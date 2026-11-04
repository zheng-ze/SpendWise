import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';

import '../../support/edit_entry_harness.dart';
import '../../support/history_pane_harness.dart';
import '../../support/ui_test_timeout.dart';

const _openSize = Size(960, 720);
const _desktopSize = Size(1440, 900);
const _phoneSize = Size(390, 844);
const _editTitle = 'Edit entry';
const _updateLabel = 'Update entry';
const _deleteKey = ValueKey('edit-entry-delete');
const _newAmount = '42';
const _headerAndRowDateCount = 2;
const _categoryLabel = 'Category';
const _editedAmount = '77';
const _persistedAmount = '5.00';

Future<HistoryPane> _pumpHistory(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
}) => pumpHistoryPane(tester, size: size, platform: platform);

Future<HistoryPane> _pumpOpenHistory(WidgetTester tester) =>
    _pumpHistory(tester, size: _openSize, platform: TargetPlatform.android);

Future<void> _openPane(WidgetTester tester, HistoryPane history) =>
    tapHistoryRow(tester, history, history.first);

Future<void> _pickCoffeeFromPane(WidgetTester tester) async {
  await tester.ensureVisible(find.text(_categoryLabel));
  await tester.tap(find.text(_categoryLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(editCoffee.name));
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
        matching: find.text(formatEntryDate(history.first.date)),
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
        .read(entryFormViewModelProvider(history.first.id).notifier)
        .setAmount(_newAmount);
    await tester.pumpAndSettle();

    await tester.tap(find.text(_updateLabel));
    await tester.pumpAndSettle();

    final saved = history.container
        .read(ledgerProvider)!
        .state
        .entries[history.first.id]!;
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
    expect(state.binnedEntries.containsKey(history.first.id), isTrue);
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

  testWidgets('a picker from the pane applies the choice to the pane draft', (
    tester,
  ) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);

    await tester.ensureVisible(find.text(_categoryLabel));
    await tester.tap(find.text(_categoryLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsOneWidget);
    await tester.tap(find.text(editCoffee.name));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsNothing);
    expect(history.pane, findsOneWidget);
    expect(history.categoryIdOf(history.first), editCoffee.id);
  }, timeout: uiTestTimeout);

  testWidgets('reselecting an entry after another shows persisted values', (
    tester,
  ) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);
    history.formOf(history.first).setAmount(_editedAmount);
    await tester.pumpAndSettle();

    await tapHistoryRow(tester, history, history.second);
    await tapHistoryRow(tester, history, history.first);

    expect(history.amountTextOf(history.first), _persistedAmount);
  }, timeout: uiTestTimeout);

  testWidgets('re-tapping the selected row keeps the edited draft', (
    tester,
  ) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);
    history.formOf(history.first).setAmount(_editedAmount);
    await tester.pumpAndSettle();

    await tapHistoryRow(tester, history, history.first);

    expect(history.pane, findsOneWidget);
    expect(history.amountTextOf(history.first), _editedAmount);
  }, timeout: uiTestTimeout);

  testWidgets('Close then reselect shows persisted values', (tester) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);
    history.formOf(history.first).setAmount(_editedAmount);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(shellDetailCloseKey));
    await tester.pumpAndSettle();
    await _openPane(tester, history);

    expect(history.pane, findsOneWidget);
    expect(history.amountTextOf(history.first), _persistedAmount);
  }, timeout: uiTestTimeout);

  testWidgets('shrinking to phone removes the pane and its open picker', (
    tester,
  ) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);
    await tester.ensureVisible(find.text(_categoryLabel));
    await tester.tap(find.text(_categoryLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsOneWidget);

    await resizeShellWindow(tester, _phoneSize);

    expect(history.pane, findsNothing);
    expect(find.byType(AppSheet), findsNothing);

    await resizeShellWindow(tester, _openSize);

    expect(history.pane, findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('opening the sheet for the pane entry leaves one owner', (
    tester,
  ) async {
    final history = await _pumpOpenHistory(tester);
    await _openPane(tester, history);
    addTearDown(() => closeAllSheets(tester));

    unawaited(
      openEditEntry(
        context: history.flowContext(tester),
        ref: history.flowRef(tester),
        entryId: history.first.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(history.pane, findsNothing);
    expect(find.byType(AppSheet), findsOneWidget);

    await _pickCoffeeFromPane(tester);

    expect(find.byType(AppSheet), findsOneWidget);
    expect(history.categoryIdOf(history.first), editCoffee.id);
  }, timeout: uiTestTimeout);
}
