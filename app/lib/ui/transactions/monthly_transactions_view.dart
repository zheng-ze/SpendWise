import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/empty_state.dart';
import 'package:spendwise/ui/transactions/month_summaries.dart';

class MonthlyTransactionsView extends StatefulWidget {
  const MonthlyTransactionsView({
    super.key,
    required this.state,
    required this.year,
    required this.onWeekTap,
  });

  final LedgerState state;
  final DateTime year;
  final void Function(DateTime month) onWeekTap;

  @override
  State<MonthlyTransactionsView> createState() =>
      _MonthlyTransactionsViewState();
}

class _MonthlyTransactionsViewState extends State<MonthlyTransactionsView> {
  DateTime? _expandedMonth;

  void _toggle(DateTime month) {
    setState(() {
      _expandedMonth = _expandedMonth == month ? null : month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = monthSummaries(widget.state, widget.year);

    if (months.isEmpty) return const TransactionsEmptyState();

    return ListView.builder(
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        final expanded = _expandedMonth == month.month;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MonthRow(
              summary: month,
              expanded: expanded,
              onTap: () => _toggle(month.month),
            ),
            if (expanded)
              for (final week in month.weeks)
                _WeekRow(
                  summary: week,
                  onTap: () => widget.onWeekTap(month.month),
                ),
          ],
        );
      },
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.summary,
    required this.expanded,
    required this.onTap,
  });

  final MonthSummary summary;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);
    final net = summary.income - summary.expenses;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: summary.isCurrentMonth ? FontWeight.bold : FontWeight.normal,
      color: summary.isCurrentMonth ? theme.colorScheme.primary : null,
    );

    return Material(
      color: summary.isCurrentMonth
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(expanded ? Icons.expand_more : Icons.chevron_right),
              const SizedBox(width: 8),
              Expanded(
                child: Text(formatMonthLabel(summary.month), style: titleStyle),
              ),
              Text(
                formatCurrency(net),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.netAmountColor(net),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.summary, required this.onTap});

  final WeekSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);
    final net = summary.income - summary.expenses;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                width: 3,
                color: summary.isCurrentWeek
                    ? theme.colorScheme.primary
                    : Colors.transparent,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(formatWeekRange(summary.range))),
              Text(
                formatCurrency(net),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.netAmountColor(net),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
