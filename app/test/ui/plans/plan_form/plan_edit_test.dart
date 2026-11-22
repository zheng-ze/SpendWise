import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/plans/plan_form/plan_form.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/row_tap.dart';
import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _frameMode = ShellLayoutMode.phone;
const _sheetTitle = 'Edit plan';
const _repeatLabel = 'Repeat';
const _newName = 'Flat rent';
const _outsideOffset = Offset(5, 5);

final _editButton = find.widgetWithText(FilledButton, _sheetTitle);
final _form = find.byType(PlanForm);
final _nameField = find
    .descendant(of: _form, matching: find.byType(TextField))
    .first;

Future<ProviderContainer> _pumpEdit(
  WidgetTester tester,
  ShellLayoutMode mode,
  Brightness brightness,
  Ledger ledger,
) async {
  final container = await pumpPlansShell(
    tester,
    mode: mode,
    ledger: ledger,
    brightness: brightness,
  );
  await tapPlan(tester, plansShellExpensePlan.id);
  await tester.tap(_editButton);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  const mode = _frameMode;
  const brightness = Brightness.light;
  final label = 'mo-plan-edit ${mode.name} (${brightness.name})';

  testWidgets('$label tapping outside writes nothing', (tester) async {
    final ledger = buildPlansShellLedger();
    await _pumpEdit(tester, mode, brightness, ledger);
    final revision = ledger.revision;

    await tester.enterText(_nameField, _newName);
    await tester.tapAt(_outsideOffset);
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
    expect(ledger.revision, revision);
  }, timeout: uiTestTimeout);

  testWidgets('a changed selection removes the open sheet', (tester) async {
    final ledger = buildPlansShellLedger();
    final container = await _pumpEdit(
      tester,
      ShellLayoutMode.open,
      Brightness.light,
      ledger,
    );
    final revision = ledger.revision;

    container
        .read(selectedPlanProvider.notifier)
        .select(plansShellIncomePlan.id);
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
    expect(ledger.revision, revision);
  }, timeout: uiTestTimeout);

  testWidgets('replacing the ledger removes the open sheet', (tester) async {
    final container = await _pumpEdit(
      tester,
      ShellLayoutMode.open,
      Brightness.light,
      buildPlansShellLedger(),
    );

    container.read(plansShellLedgerFixture.notifier).state =
        buildPlansShellLedger();
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('removing the form also closes its open picker', (tester) async {
    final container = await _pumpEdit(
      tester,
      ShellLayoutMode.open,
      Brightness.light,
      buildPlansShellLedger(),
    );
    await tapRow(tester, find.widgetWithText(ListTile, _repeatLabel));
    expect(find.byType(AppPickerSheet), findsOneWidget);

    container.read(plansShellLedgerFixture.notifier).state =
        buildPlansShellLedger();
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
    expect(find.byType(AppPickerSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('deleting the plan removes the open sheet', (tester) async {
    final ledger = buildPlansShellLedger();
    await _pumpEdit(tester, ShellLayoutMode.open, Brightness.light, ledger);

    ledger.deletePlan(plansShellExpensePlan.id);
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
  }, timeout: uiTestTimeout);
}
