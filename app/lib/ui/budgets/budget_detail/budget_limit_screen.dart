import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart'
    show DefaultLimitTarget, LimitEditTarget, MonthLimitTarget;
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_view_model.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

/// Shows the limit-edit sheet for [target] and returns the entered amount,
/// or null if the user backed out.
Future<Decimal?> showBudgetLimitEditSheet({
  required BuildContext context,
  required LimitEditTarget target,
}) {
  final (title, subtitle, current) = switch (target) {
    DefaultLimitTarget(:final current, :final effectiveFromMonth) => (
      'Default Budget',
      'Applies from '
          '${formatMonthLabel(DateTime.utc(effectiveFromMonth.year, effectiveFromMonth.month))} '
          'onward',
      current,
    ),
    MonthLimitTarget(:final month, :final current) => (
      formatMonthLabel(DateTime.utc(month.year, month.month)),
      null,
      current,
    ),
  };

  return showModalBottomSheet<Decimal>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => BudgetLimitEditSheet(
      title: title,
      subtitle: subtitle,
      current: current,
    ),
  );
}

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

class _BudgetLimitScreenBody extends StatelessWidget {
  const _BudgetLimitScreenBody({
    required this.viewState,
    required this.viewModel,
  });

  final BudgetLimitViewState viewState;
  final BudgetLimitViewModel viewModel;

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
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Applies to months with no override'),
      trailing: Text(
        defaultLimit == null ? '—' : formatCurrency(defaultLimit),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: viewModel.requestEditDefault,
    );
    final yearSelector = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          trailing: Text(formatCurrency(effectiveLimit(budget, month))),
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
            const Divider(height: 1),
            yearSelector,
            ...monthRows,
          ],
        ),
      ),
    );
  }
}

class BudgetLimitEditSheet extends StatefulWidget {
  const BudgetLimitEditSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.current,
  });

  final String title;
  final String? subtitle;
  final Decimal current;

  @override
  State<BudgetLimitEditSheet> createState() => _BudgetLimitEditSheetState();
}

class _BudgetLimitEditSheetState extends State<BudgetLimitEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: formatPlainAmount(widget.current),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              AmountField(
                controller: _controller,
                allowsNegative: false,
                hintText: 'Limit',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final amount = parseAmountInput(_controller.text);
                    Navigator.of(context).pop(amount);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
