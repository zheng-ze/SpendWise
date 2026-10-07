import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_list/empty_state.dart';
import 'package:spendwise/ui/transactions/monthly/month_summaries.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

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

  static const _monthHorizontalPadding = 16.0;
  static const _monthVerticalPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = summary.income - summary.expenses;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: summary.isCurrentMonth ? FontWeight.bold : FontWeight.normal,
      color: summary.isCurrentMonth ? theme.colorScheme.primary : null,
    );

    return _TransactionSummaryRow(
      background: summary.isCurrentMonth ? context.colors.tint : null,
      padding: const EdgeInsets.symmetric(
        horizontal: _monthHorizontalPadding,
        vertical: _monthVerticalPadding,
      ),
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

  static const _weekHorizontalPadding = 16.0;
  static const _weekVerticalPadding = 10.0;
  static const _currentWeekBorderWidth = 3.0;
  static const _inactiveBorderColor = Color(0x00000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = summary.income - summary.expenses;

    return _TransactionSummaryRow(
      background: theme.colorScheme.surfaceContainerHighest,
      border: Border(
        left: BorderSide(
          width: _currentWeekBorderWidth,
          color: summary.isCurrentWeek
              ? theme.colorScheme.primary
              : _inactiveBorderColor,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _weekHorizontalPadding,
        vertical: _weekVerticalPadding,
      ),
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

  static const _leadingGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final labelText = Expanded(child: Text(label, style: labelStyle));
    final netText = Text(
      formatMoney(net, symbol: false),
      style: netStyle?.copyWith(
        color: AmountStyle.of(context, signedValue: net).color,
      ),
    );
    final rowContent = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: _leadingGap)],
        labelText,
        netText,
      ],
    );
    final container = Container(
      decoration: border == null ? null : BoxDecoration(border: border),
      padding: padding,
      child: rowContent,
    );
    final ink = InkWell(onTap: onTap, child: container);

    return Material(color: background, child: ink);
  }
}
