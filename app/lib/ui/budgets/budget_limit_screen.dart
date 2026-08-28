import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/month_year_selector.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

class BudgetLimitScreen extends StatefulWidget {
  const BudgetLimitScreen({
    super.key,
    required this.ledger,
    required this.budgetID,
  });

  final Ledger ledger;
  final String budgetID;

  @override
  State<BudgetLimitScreen> createState() => _BudgetLimitScreenState();
}

class _BudgetLimitScreenState extends State<BudgetLimitScreen> {
  late DateTime _displayedYear = DateTime.utc(DateTime.now().toUtc().year);
  LedgerError? _error;

  void _applyLimitChange(void Function() change) {
    try {
      change();
      if (!mounted) return;
      setState(() => _error = null);
    } on LedgerError catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _editDefault(Decimal current) async {
    final now = DateTime.now().toUtc();
    final nextMonth = YearMonth.fromUtc(DateTime.utc(now.year, now.month + 1));
    final entered = await showModalBottomSheet<Decimal>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _LimitEditSheet(
        title: 'Default Budget',
        subtitle:
            'Applies from ${formatMonthLabel(DateTime.utc(nextMonth.year, nextMonth.month))} onward',
        current: current,
      ),
    );
    if (entered == null || entered <= Decimal.zero) return;

    _applyLimitChange(
      () =>
          widget.ledger.updateBudgetAmount(widget.budgetID, entered, nextMonth),
    );
  }

  Future<void> _editMonth(YearMonth month, Decimal current) async {
    final entered = await showModalBottomSheet<Decimal>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _LimitEditSheet(
        title: formatMonthLabel(DateTime.utc(month.year, month.month)),
        current: current,
      ),
    );
    if (entered == null || entered <= Decimal.zero) return;

    _applyLimitChange(
      () =>
          widget.ledger.setBudgetMonthOverride(widget.budgetID, month, entered),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.ledger.state.budgets[widget.budgetID];
    if (budget == null) {
      return const Scaffold(body: Center(child: Text('Budget deleted')));
    }

    final defaultLimit = budget.limitEvents
        .where((event) => event.kind == LimitEventKind.defaultLimit)
        .map((event) => event.value)
        .lastOrNull;

    final months = [
      for (var i = 11; i >= 0; i--) YearMonth(_displayedYear.year, i + 1),
    ];

    final errorSection = ErrorSection(subject: 'budget limit', error: _error);
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
      onTap: () => _editDefault(defaultLimit ?? Decimal.zero),
    );
    final yearSelector = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: MonthYearSelector(
          value: _displayedYear,
          step: MonthYearStep.year,
          onChanged: (year) => setState(() => _displayedYear = year),
        ),
      ),
    );
    final monthRows = [
      for (final month in months)
        ListTile(
          title: Text(formatMonthLabel(DateTime.utc(month.year, month.month))),
          trailing: Text(formatCurrency(effectiveLimit(budget, month))),
          onTap: () => _editMonth(month, effectiveLimit(budget, month)),
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

class _LimitEditSheet extends StatefulWidget {
  const _LimitEditSheet({
    required this.title,
    this.subtitle,
    required this.current,
  });

  final String title;
  final String? subtitle;
  final Decimal current;

  @override
  State<_LimitEditSheet> createState() => _LimitEditSheetState();
}

class _LimitEditSheetState extends State<_LimitEditSheet> {
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
