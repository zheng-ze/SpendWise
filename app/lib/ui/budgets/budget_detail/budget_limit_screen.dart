import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail/budget_limit_view_model.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/month_year_selector.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

// MARK: - BudgetLimitScreen
class BudgetLimitScreen extends ConsumerWidget {
  const BudgetLimitScreen({super.key, required this.budgetID});

  final String budgetID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(budgetLimitViewModelProvider(budgetID));

    return asyncState.when(
      data: (viewState) => _BudgetLimitScreenBody(
        viewState: viewState,
        viewModel: ref.read(budgetLimitViewModelProvider(budgetID).notifier),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

// MARK: - BudgetLimitScreenBody
class _BudgetLimitScreenBody extends StatelessWidget {
  const _BudgetLimitScreenBody({
    required this.viewState,
    required this.viewModel,
  });

  final BudgetLimitViewState viewState;
  final BudgetLimitViewModel viewModel;

  static const _yearSelectorVerticalPadding = 4.0;
  static const _dividerHeight = 1.0;
  static const _emphasisWeight = FontWeight.bold;

  @override
  Widget build(BuildContext context) {
    final budget = viewState.budget;
    if (budget == null) {
      return const Scaffold(body: Center(child: Text('Budget deleted')));
    }

    final defaultLimit = viewState.defaultLimit;
    final errorSection = ErrorSection(
      subject: 'budget limit',
      error: viewState.error,
    );
    final defaultRow = ListTile(
      title: const Text(
        'Default Budget',
        style: TextStyle(fontWeight: _emphasisWeight),
      ),
      subtitle: const Text('Applies to months with no override'),
      trailing: Text(
        defaultLimit == null ? '—' : formatMoney(defaultLimit, symbol: false),
        style: const TextStyle(fontWeight: _emphasisWeight),
      ),
      onTap: viewModel.requestEditDefault,
    );
    final yearSelector = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: _yearSelectorVerticalPadding,
      ),
      child: Center(
        child: MonthYearSelector(
          value: viewState.displayedYear,
          step: MonthYearStep.year,
          onChanged: viewModel.changeYear,
        ),
      ),
    );
    final monthRows = [
      for (final month in viewState.months)
        ListTile(
          title: Text(formatMonthLabel(DateTime.utc(month.year, month.month))),
          trailing: Text(
            formatMoney(effectiveLimit(budget, month), symbol: false),
          ),
          onTap: () => viewModel.requestEditMonth(month),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Budget Limit')),
      body: SafeArea(
        child: ListView(
          children: [
            errorSection,
            defaultRow,
            const Divider(height: _dividerHeight),
            yearSelector,
            ...monthRows,
          ],
        ),
      ),
    );
  }
}
