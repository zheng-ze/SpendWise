import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/number_pad_support.dart';
import '../../../support/pump_app.dart';
import '../../../support/sheet_contract.dart';
import '../../../support/ui_test_timeout.dart';
import '../budget_shell_test_support.dart';

const _addLabel = 'Add budget';
const _saveLabel = 'Save budget';
const _pickerTitle = 'Choose category';
const _budgetedSubtitle = 'Has a budget';
const _dragDown = Offset(0, 900);
const _outsideTap = Offset(5, 5);

TransactionCategory _category(String name, {String? parentID}) =>
    TransactionCategory(
      name: name,
      kind: CategoryKind.expense,
      colorHex: '#00AA00',
      includeInAnalysis: true,
      parentID: parentID,
      symbol: 'restaurant',
    );

final _food = _category('Food');
final _dining = _category('Dining', parentID: _food.id);
final _transport = _category('Transport');

Ledger _ledgerWith({List<Budget> budgets = const []}) {
  final categories = [_food, _dining, _transport];
  return Ledger(
    state: LedgerState(
      categories: {for (final category in categories) category.id: category},
      budgets: {for (final budget in budgets) budget.id: budget},
    ),
  );
}

Budget _budgetFor(String? categoryID) =>
    Budget(categoryID: categoryID, limit: Decimal.fromInt(10));

class _GatedFormNotifier extends BudgetFormNotifier {
  _GatedFormNotifier(super.draftKey, this.gate);

  final Future<void> Function() gate;

  @override
  Future<BudgetFormViewState> build() {
    final state = super.build();
    return gate().then((_) => state);
  }
}

class _DataUnavailable {
  @override
  String toString() => 'StateError: Data unavailable';
}

Future<ProviderContainer> _pumpFlow(
  WidgetTester tester,
  Ledger ledger, {
  Future<void> Function()? gate,
}) async {
  await pumpApp(
    tester,
    const BudgetsFlow(),
    ledger: ledger,
    overrides: [
      if (gate != null)
        budgetFormViewModelProvider.overrideWith2(
          (key) => _GatedFormNotifier(key, gate),
        ),
    ],
  );
  return ProviderScope.containerOf(tester.element(find.byType(BudgetsFlow)));
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text(_addLabel));
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(AppSheet), matching: finder);

Future<void> _dragDismiss(WidgetTester tester) async {
  await tester.drag(_inSheet(find.text(_addLabel)), _dragDown);
  await tester.pumpAndSettle();
}

Future<void> _enterAmount(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tapPadLabel(tester, digit);
  }
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Category'));
  await tester.pumpAndSettle();
}

Future<void> _pickRow(WidgetTester tester, String label) async {
  await tester.tap(_inSheet(find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mo-budget-add shows the copy without Cancel and saves once', (
    tester,
  ) async {
    final ledger = _ledgerWith();
    await _pumpFlow(tester, ledger);
    await _openForm(tester);

    expect(_inSheet(find.text(_addLabel)), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('All spending'), findsOneWidget);
    expect(find.text('Monthly limit / SGD'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(NumberPad), findsOneWidget);

    await _enterAmount(tester, '25.5');
    await tester.tap(find.text(_saveLabel));
    await tester.pumpAndSettle();

    expect(find.byType(BudgetForm), findsNothing);
    final budget = ledger.state.budgets.values.single;
    expect(budget.categoryID, isNull);
    expect(budget.limit, Decimal.parse('25.5'));
  }, timeout: uiTestTimeout);

  testWidgets(
    'mo-budget-add reopens with an empty draft and admits one sheet',
    (tester) async {
      final container = await _pumpFlow(tester, _ledgerWith());
      await _openForm(tester);
      await _enterAmount(tester, '7');
      container.read(budgetsListViewModelProvider.notifier).requestNewBudget();
      await tester.pumpAndSettle();
      expect(find.byType(BudgetForm), findsOneWidget);

      await _dragDismiss(tester);
      await _openForm(tester);

      expect(find.text('0.00'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('mo-budget-add drag-down dismissal on phone writes nothing', (
    tester,
  ) async {
    final ledger = _ledgerWith();
    await _pumpFlow(tester, ledger);
    await _openForm(tester);
    await _enterAmount(tester, '9');

    await _dragDismiss(tester);

    expect(find.byType(BudgetForm), findsNothing);
    expect(ledger.state.budgets, isEmpty);
  }, timeout: uiTestTimeout);

  testWidgets('mo-budget-pick disables budgeted rows and picks a child', (
    tester,
  ) async {
    final budgets = [_budgetFor(null), _budgetFor(_food.id)];
    final ledger = _ledgerWith(budgets: budgets);
    await _pumpFlow(tester, ledger);
    await _openForm(tester);
    expect(find.text('Choose'), findsOneWidget);

    await _openPicker(tester);
    expect(find.text(_pickerTitle), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text(_budgetedSubtitle), findsNWidgets(2));
    await _pickRow(tester, 'All spending');
    await _pickRow(tester, 'Food');
    expect(find.text(_pickerTitle), findsOneWidget);

    await _pickRow(tester, 'Dining');

    expect(find.text(_pickerTitle), findsNothing);
    expect(_inSheet(find.text('Dining')), findsOneWidget);
    await _enterAmount(tester, '12');
    await tester.tap(find.text(_saveLabel));
    await tester.pumpAndSettle();
    expect(ledger.state.budgets, hasLength(3));
    expect(ledger.state.budgets.values.last.categoryID, _dining.id);
  }, timeout: uiTestTimeout);

  testWidgets('mo-budget-pick dismissal leaves the category unchanged', (
    tester,
  ) async {
    await _pumpFlow(tester, _ledgerWith());
    await _openForm(tester);

    await _openPicker(tester);
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(find.text(_pickerTitle), findsNothing);
    expect(find.byType(BudgetForm), findsOneWidget);
    expect(find.text('All spending'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('le-budget-add-load shows Loading inside the sheet', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pumpApp(
      tester,
      const BudgetsFlow(),
      ledger: _ledgerWith(),
      overrides: [
        budgetFormViewModelProvider.overrideWith2(
          (key) => _GatedFormNotifier(key, () => gate.future),
        ),
      ],
      settle: false,
    );
    await tester.pump();
    await tester.tap(find.text(_addLabel));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_inSheet(find.text(_addLabel)), findsOneWidget);
    expect(_inSheet(find.text('Loading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_saveLabel), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsNothing);
    expect(find.text(_saveLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'le-budget-add-err shows the thrown reason and Try again recovers',
    (tester) async {
      var attempts = 0;
      await _pumpFlow(
        tester,
        _ledgerWith(),
        gate: () async {
          attempts++;
          if (attempts == 1) throw _DataUnavailable();
          if (attempts == 2) throw StateError('Data unavailable');
        },
      );
      await _openForm(tester);

      expectAlertOutsideSheet(tester);
      expect(
        find.text(
          "Couldn't load the budget form\nStateError: Data unavailable",
        ),
        findsOneWidget,
      );
      expect(find.text(_saveLabel), findsNothing);
      final route = ModalRoute.of(tester.element(find.byType(BudgetForm)));

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't load the budget form\nBad state: Data unavailable"),
        findsOneWidget,
      );

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(SheetAlert), findsNothing);
      expect(find.text(_saveLabel), findsOneWidget);
      expect(ModalRoute.of(tester.element(find.byType(BudgetForm))), route);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'sf-budget keeps the draft and shows the reason outside the sheet',
    (tester) async {
      final ledger = _ledgerWith();
      await _pumpFlow(tester, ledger);
      await _openForm(tester);
      await _enterAmount(tester, '25');
      ledger.addBudget(null, Decimal.fromInt(5));

      await tester.tap(find.text(_saveLabel));
      await tester.pumpAndSettle();

      expectAlertOutsideSheet(tester);
      expect(
        find.text('Could not save budget\nthat category already has a budget.'),
        findsOneWidget,
      );
      expect(find.text('25'), findsOneWidget);
      expect(find.text(_saveLabel), findsOneWidget);
      expect(ledger.state.budgets, hasLength(1));
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a live resize keeps the route and draft and swaps pad for field',
    (tester) async {
      final container = await pumpBudgetShell(
        tester,
        mode: ShellLayoutMode.open,
      );
      await _openForm(tester);
      await _enterAmount(tester, '42');
      await _openPicker(tester);
      final state = tester.state(find.byType(BudgetForm));

      container.read(budgetShellModeFixture.notifier).state =
          ShellLayoutMode.desktop;
      await tester.pumpAndSettle();
      expect(find.text(_pickerTitle), findsOneWidget);
      await tester.tapAt(_outsideTap);
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(BudgetForm)), same(state));
      expect(find.byType(NumberPad), findsNothing);
      final field = tester.widget<AmountField>(find.byType(AmountField));
      expect(field.controller.text, '42');
    },
    timeout: uiTestTimeout,
  );
}
