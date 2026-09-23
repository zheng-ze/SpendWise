import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_list/empty_state.dart';
import 'package:spendwise/ui/transactions/monthly/month_summaries.dart';

class MonthlyTransactionsView extends StatefulWidget {
  const MonthlyTransactionsView({
    super.key,
    required this.summaries,
    required this.onWeekTap,
  });

  final List<MonthSummary> summaries;
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
    final months = widget.summaries;

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
    final net = summary.income - summary.expenses;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: summary.isCurrentMonth ? FontWeight.bold : FontWeight.normal,
      color: summary.isCurrentMonth ? theme.colorScheme.primary : null,
    );

    return _TransactionSummaryRow(
      background: summary.isCurrentMonth
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      leading: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
      label: formatMonthLabel(summary.month),
      labelStyle: titleStyle,
      net: net,
      netStyle: theme.textTheme.titleSmall,
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
    final net = summary.income - summary.expenses;

    return _TransactionSummaryRow(
      background: theme.colorScheme.surfaceContainerHighest,
      border: Border(
        left: BorderSide(
          width: 3,
          color: summary.isCurrentWeek
              ? theme.colorScheme.primary
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onTap: onTap,
      label: formatWeekRange(summary.range),
      net: net,
      netStyle: theme.textTheme.bodyMedium,
    );
  }
}

class _TransactionSummaryRow extends StatelessWidget {
  const _TransactionSummaryRow({
    this.background,
    this.border,
    this.leading,
    required this.label,
    this.labelStyle,
    required this.net,
    this.netStyle,
    required this.padding,
    required this.onTap,
  });

  final Color? background;
  final BoxBorder? border;
  final Widget? leading;
  final String label;
  final TextStyle? labelStyle;
  final Decimal net;
  final TextStyle? netStyle;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AmountColors.of(Theme.of(context));

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: border == null ? null : BoxDecoration(border: border),
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Expanded(child: Text(label, style: labelStyle)),
              Text(
                formatCurrency(net),
                style: netStyle?.copyWith(color: colors.netAmountColor(net)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
