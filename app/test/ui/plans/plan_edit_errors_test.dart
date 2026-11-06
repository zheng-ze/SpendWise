import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/plans/plan_form.dart';
import 'package:spendwise/ui/plans/plan_form_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/sheet_contract.dart';
import '../../support/ui_test_timeout.dart';
import 'plans_shell_test_support.dart';

const _modes = [ShellLayoutMode.phone, ShellLayoutMode.open];
const _sheetTitle = 'Edit plan';
const _loadErrorMessage =
    "Couldn't load this plan\nBad state: Data unavailable";
const _saveLabel = 'Save plan';
const _retryLabel = 'Try again';
const _saveErrorTitle = 'Could not save plan';
const _draftName = 'Flat rent';
const _loadingLabel = 'Loading';
final _endBeforeFirstDate = DateTime.utc(2025, 1, 1);

final _editButton = find.widgetWithText(FilledButton, _sheetTitle);
final _form = find.byType(PlanForm);
final _nameField = find
    .descendant(of: _form, matching: find.byType(TextField))
    .first;

class _FlakyPlanFormNotifier extends PlanFormNotifier {
  _FlakyPlanFormNotifier(super.planId, this._shouldFail);

  final bool Function() _shouldFail;

  @override
  Future<PlanFormViewState> build() {
    if (_shouldFail()) throw StateError('Data unavailable');
    return super.build();
  }
}

Future<ProviderContainer> _pumpEdit(
  WidgetTester tester,
  ShellLayoutMode mode,
  Brightness brightness, {
  bool Function()? shouldFail,
}) async {
  final container = await pumpPlansShell(
    tester,
    mode: mode,
    ledger: buildPlansShellLedger(),
    brightness: brightness,
    overrides: [
      if (shouldFail != null)
        planFormViewModelProvider(plansShellExpensePlan.id).overrideWith(
          () => _FlakyPlanFormNotifier(plansShellExpensePlan.id, shouldFail),
        ),
    ],
  );
  await tapPlan(tester, plansShellExpensePlan.id);
  await tester.tap(_editButton);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final mode in _modes) {
      final label = '${mode.name} (${brightness.name})';

      testWidgets(
        'le-plan-edit-err $label shows the reason and Try again recovers',
        (tester) async {
          var shouldFail = true;
          await _pumpEdit(
            tester,
            mode,
            brightness,
            shouldFail: () => shouldFail,
          );

          expectAlertOutsideSheet(tester);
          expect(find.text(_loadErrorMessage), findsOneWidget);
          expect(find.text(_saveLabel), findsNothing);

          shouldFail = false;
          await tester.tap(find.text(_retryLabel));
          await tester.pumpAndSettle();

          expect(find.byType(SheetAlert), findsNothing);
          expect(find.text(_saveLabel), findsOneWidget);
        },
        timeout: uiTestTimeout,
      );

      testWidgets(
        'mo-plan-edit $label save error keeps the draft and shows the alert',
        (tester) async {
          final container = await _pumpEdit(tester, mode, brightness);
          await tester.enterText(_nameField, _draftName);
          final viewModel = container.read(
            planFormViewModelProvider(plansShellExpensePlan.id).notifier,
          );
          viewModel.setHasEndDate(true);
          viewModel.applyPickedEndDate(_endBeforeFirstDate);
          await tester.pumpAndSettle();

          await tester.tap(find.text(_saveLabel));
          await tester.pumpAndSettle();

          expect(find.textContaining(_saveErrorTitle), findsOneWidget);
          expect(find.text(_draftName), findsOneWidget);
        },
        timeout: uiTestTimeout,
      );
    }
  }

  testWidgets('the form shows Loading until the plan loads', (tester) async {
    await pumpPlansShell(
      tester,
      mode: ShellLayoutMode.phone,
      ledger: buildPlansShellLedger(),
      brightness: Brightness.light,
    );
    await tapPlan(tester, plansShellExpensePlan.id);
    await tester.tap(_editButton);
    await tester.pump();

    expect(find.text(_loadingLabel), findsOneWidget);
    expect(find.text(_sheetTitle), findsWidgets);
  }, timeout: uiTestTimeout);
}
