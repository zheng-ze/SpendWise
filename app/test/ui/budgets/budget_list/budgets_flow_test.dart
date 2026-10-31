import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';

import '../../../support/ui_test_timeout.dart';

const _editTooltip = 'Edit limit';
const _limitEditor = BudgetLimitEditSheet;

final _budget = Budget(id: 'b1', categoryID: null, limit: Decimal.parse('100'));
final _other = Budget(id: 'b2', categoryID: null, limit: Decimal.parse('30'));

Future<ProviderContainer> _pumpFlow(
  WidgetTester tester,
  Ledger ledger, {
  Widget Function(Widget flow)? wrap,
}) async {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(ledger),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);
  const flow = BudgetsFlow();
  final home = wrap == null ? flow : wrap(flow);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Widget _destinationWrapper(ValueNotifier<bool> active, Widget flow) =>
    ValueListenableBuilder<bool>(
      valueListenable: active,
      builder: (_, isActive, _) =>
          DestinationActivity(active: isActive, child: flow),
    );

Future<(ProviderContainer, ValueNotifier<bool>)> _pumpTogglableFlow(
  WidgetTester tester,
  Ledger ledger,
) async {
  final active = ValueNotifier(true);
  addTearDown(active.dispose);
  final container = await _pumpFlow(
    tester,
    ledger,
    wrap: (flow) => _destinationWrapper(active, flow),
  );
  return (container, active);
}

Future<void> _openDetail(
  WidgetTester tester,
  ProviderContainer container,
  String budgetID,
) async {
  container
      .read(budgetsListViewModelProvider.notifier)
      .requestBudgetDetail(budgetID);
  await tester.pumpAndSettle();
}

String _editorText(WidgetTester tester) {
  final field = find.descendant(
    of: find.byType(_limitEditor),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(field).controller.text;
}

void main() {
  testWidgets(
    'detail providers stay alive through route exit and then dispose',
    (tester) async {
      final ledger = Ledger(state: LedgerState(budgets: {_budget.id: _budget}));
      final container = await _pumpFlow(tester, ledger);
      await _openDetail(tester, container, _budget.id);

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.exists(budgetDetailViewModelProvider(_budget.id)),
        isTrue,
      );
      expect(container.exists(budgetDetailContextProvider(_budget.id)), isTrue);

      await tester.pumpAndSettle();
      expect(
        container.exists(budgetDetailViewModelProvider(_budget.id)),
        isFalse,
      );
      expect(
        container.exists(budgetDetailContextProvider(_budget.id)),
        isFalse,
      );
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Edit on the detail page opens the limit editor prefilled with the limit',
    (tester) async {
      final ledger = Ledger(state: LedgerState(budgets: {_budget.id: _budget}));
      final container = await _pumpFlow(tester, ledger);
      await _openDetail(tester, container, _budget.id);

      await tester.tap(find.byTooltip(_editTooltip));
      await tester.pumpAndSettle();

      expect(find.byType(_limitEditor), findsOneWidget);
      expect(_editorText(tester), '100.00');
    },
    timeout: uiTestTimeout,
  );

  testWidgets('a retained step opens the editor with the live limit after the '
      'destination returns', (tester) async {
    final ledger = Ledger(state: LedgerState(budgets: {_budget.id: _budget}));
    final (container, active) = await _pumpTogglableFlow(tester, ledger);
    await _openDetail(tester, container, _budget.id);
    active.value = false;
    await tester.pumpAndSettle();
    container
        .read(budgetDetailViewModelProvider(_budget.id).notifier)
        .requestLimitEdit();
    await tester.pumpAndSettle();
    expect(find.byType(_limitEditor), findsNothing);

    ledger.updateBudgetLimit(_budget.id, Decimal.parse('250'));
    active.value = true;
    await tester.pumpAndSettle();

    expect(find.byType(_limitEditor), findsOneWidget);
    expect(_editorText(tester), '250.00');
  }, timeout: uiTestTimeout);

  testWidgets(
    'a step retained for a deleted budget opens no editor and leaves the '
    'next Edit working',
    (tester) async {
      final ledger = Ledger(
        state: LedgerState(budgets: {_budget.id: _budget, _other.id: _other}),
      );
      final (container, active) = await _pumpTogglableFlow(tester, ledger);
      await _openDetail(tester, container, _budget.id);
      active.value = false;
      await tester.pumpAndSettle();
      container
          .read(budgetDetailViewModelProvider(_budget.id).notifier)
          .requestLimitEdit();
      ledger.deleteBudget(_budget.id);
      await tester.pumpAndSettle();

      active.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(_limitEditor), findsNothing);

      await _openDetail(tester, container, _other.id);
      await tester.tap(find.byTooltip(_editTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(_limitEditor), findsOneWidget);
      expect(_editorText(tester), '30.00');
    },
    timeout: uiTestTimeout,
  );

  testWidgets('a second limit request while the editor is open is dropped', (
    tester,
  ) async {
    final ledger = Ledger(state: LedgerState(budgets: {_budget.id: _budget}));
    final container = await _pumpFlow(tester, ledger);
    await _openDetail(tester, container, _budget.id);
    final detail = container.read(
      budgetDetailViewModelProvider(_budget.id).notifier,
    );
    detail.requestLimitEdit();
    await tester.pumpAndSettle();
    detail.requestLimitEdit();
    await tester.pumpAndSettle();
    expect(find.byType(_limitEditor), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(_limitEditor), findsNothing);
  }, timeout: uiTestTimeout);
}
