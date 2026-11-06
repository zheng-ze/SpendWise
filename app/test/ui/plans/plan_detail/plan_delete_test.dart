import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_detail_screen.dart';
import 'package:spendwise/ui/plans/plan_detail/plan_pane.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _modes = [
  ShellLayoutMode.phone,
  ShellLayoutMode.open,
  ShellLayoutMode.desktop,
];
const _deleteLabel = 'Delete plan';
const _cancelLabel = 'Cancel';
const _confirmLabel = 'Delete';
const _confirmTitle = 'Delete the Rent plan?';
const _confirmBody = 'Entries it already added stay in History.';
const _outsideOffset = Offset(5, 5);

final _confirmButton = find.widgetWithText(FilledButton, _confirmLabel);
final _cancelButton = find.widgetWithText(TextButton, _cancelLabel);

final _generatedEntry = Entry(
  date: DateTime.utc(2026, 3, 5),
  amount: Decimal.parse('-1200'),
  name: 'Rent',
  sourceID: plansShellChecking.id,
);

Ledger _ledgerWithGeneratedEntry() {
  final base = buildPlansShellLedger().state;
  return Ledger(
    state: LedgerState(
      moneySources: base.moneySources,
      categories: base.categories,
      entries: {...base.entries, _generatedEntry.id: _generatedEntry},
      plans: base.plans,
    ),
  );
}

Finder _detail(ShellLayoutMode mode) => mode == ShellLayoutMode.phone
    ? find.byType(PlanDetailScreen)
    : find.byType(PlanPaneBody);

Future<ProviderContainer> _pumpConfirmation(
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
  await tester.tap(find.text(_deleteLabel));
  await tester.pumpAndSettle();
  return container;
}

void _expectPlanKept(Ledger ledger, ProviderContainer container) {
  expect(ledger.state.plans.containsKey(plansShellExpensePlan.id), isTrue);
  expect(container.read(selectedPlanProvider), plansShellExpensePlan.id);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final mode in _modes) {
      final label = 'mo-plan-delete ${mode.name} (${brightness.name})';

      testWidgets('$label shows the confirmation copy', (tester) async {
        final ledger = _ledgerWithGeneratedEntry();
        await _pumpConfirmation(tester, mode, brightness, ledger);

        expect(find.text(_confirmTitle), findsOneWidget);
        expect(find.text(_confirmBody), findsOneWidget);
        expect(_cancelButton, findsOneWidget);
        expect(_confirmButton, findsOneWidget);
      }, timeout: uiTestTimeout);

      testWidgets('$label Cancel writes nothing and keeps the detail', (
        tester,
      ) async {
        final ledger = _ledgerWithGeneratedEntry();
        final container = await _pumpConfirmation(
          tester,
          mode,
          brightness,
          ledger,
        );
        final revision = ledger.revision;

        await tester.tap(_cancelButton);
        await tester.pumpAndSettle();

        expect(find.text(_confirmTitle), findsNothing);
        expect(ledger.revision, revision);
        expect(_detail(mode), findsOneWidget);
        _expectPlanKept(ledger, container);
      }, timeout: uiTestTimeout);

      testWidgets('$label dismissing writes nothing and keeps the detail', (
        tester,
      ) async {
        final ledger = _ledgerWithGeneratedEntry();
        final container = await _pumpConfirmation(
          tester,
          mode,
          brightness,
          ledger,
        );
        final revision = ledger.revision;

        await tester.tapAt(_outsideOffset);
        await tester.pumpAndSettle();

        expect(find.text(_confirmTitle), findsNothing);
        expect(ledger.revision, revision);
        expect(_detail(mode), findsOneWidget);
        _expectPlanKept(ledger, container);
      }, timeout: uiTestTimeout);

      testWidgets('$label Delete removes the plan and keeps its entries', (
        tester,
      ) async {
        final ledger = _ledgerWithGeneratedEntry();
        final container = await _pumpConfirmation(
          tester,
          mode,
          brightness,
          ledger,
        );
        final revision = ledger.revision;

        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        expect(ledger.revision, revision + 1);
        expect(
          ledger.state.plans.containsKey(plansShellExpensePlan.id),
          isFalse,
        );
        expect(ledger.state.plans.length, 2);
        expect(ledger.state.entries.containsKey(_generatedEntry.id), isTrue);
        expect(container.read(selectedPlanProvider), isNull);
        expect(_detail(mode), findsNothing);
      }, timeout: uiTestTimeout);
    }
  }
}
