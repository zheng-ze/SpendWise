import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/budgets/budget_spend.dart';

const _barHeight = 22.0;

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.budget,
    required this.month,
    required this.items,
    required this.state,
    this.isSubcategory = false,
    this.onTap,
  });

  final Budget budget;
  final YearMonth month;
  final List<AnalysisItem> items;
  final LedgerState state;

  /// Indents the card to show it grouped under its parent category.
  final bool isSubcategory;
  final VoidCallback? onTap;

  (String, Color) _categoryDisplay(LedgerState state) {
    final categoryID = budget.categoryID;
    if (categoryID == null) return ('Overall', colorHexFallback);

    final category = state.categories[categoryID];
    if (category == null) return ('(category deleted)', colorHexFallback);
    return (category.name, parseColorHex(category.colorHex));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);
    final (name, color) = _categoryDisplay(state);

    final limit = effectiveLimit(budget, month);
    final spend = budgetSpend(budget, month, items, state);
    final remaining = limit - spend;
    final overLimit = spend > limit;
    final percentOfLimit = limit == Decimal.zero
        ? (spend == Decimal.zero ? 0.0 : 1.0)
        : (spend / limit).toDouble();

    final header = _BudgetCardHeader(
      name: name,
      limit: limit,
      isSubcategory: isSubcategory,
    );
    final bar = _BudgetCardBar(
      percentOfLimit: percentOfLimit,
      color: overLimit ? colors.loss : color,
    );
    final footer = _BudgetCardFooter(
      spend: spend,
      remaining: remaining,
      overLimit: overLimit,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isSubcategory ? 32 : 16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 6),
            bar,
            const SizedBox(height: 4),
            footer,
          ],
        ),
      ),
    );
  }
}

class _BudgetCardHeader extends StatelessWidget {
  const _BudgetCardHeader({
    required this.name,
    required this.limit,
    required this.isSubcategory,
  });

  final String name;
  final Decimal limit;
  final bool isSubcategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style:
                (isSubcategory
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Text(
          formatCurrency(limit),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _BudgetCardBar extends StatelessWidget {
  const _BudgetCardBar({required this.percentOfLimit, required this.color});

  final double percentOfLimit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = percentOfLimit.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_barHeight / 2),
      child: Stack(
        children: [
          Container(
            height: _barHeight,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          FractionallySizedBox(
            widthFactor: fraction,
            child: Container(height: _barHeight, color: color),
          ),
          Positioned.fill(
            child: _BudgetCardBarLabel(
              percentOfLimit: percentOfLimit,
              fraction: fraction,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCardBarLabel extends StatelessWidget {
  const _BudgetCardBarLabel({
    required this.percentOfLimit,
    required this.fraction,
  });

  final double percentOfLimit;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          formatPercent(percentOfLimit),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: fraction >= 0.5
                ? Colors.white
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _BudgetCardFooter extends StatelessWidget {
  const _BudgetCardFooter({
    required this.spend,
    required this.remaining,
    required this.overLimit,
  });

  final Decimal spend;
  final Decimal remaining;
  final bool overLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);

    return Row(
      children: [
        if (overLimit)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: colors.loss,
            ),
          ),
        Text(
          formatCurrency(spend),
          style: theme.textTheme.bodySmall?.copyWith(
            color: overLimit ? colors.loss : colors.neutral,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        Text(
          remaining < Decimal.zero
              ? '-${formatCurrency(remaining.abs())}'
              : formatCurrency(remaining),
          style: theme.textTheme.bodySmall?.copyWith(
            color: overLimit ? colors.loss : theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class BudgetsEmptyState extends StatelessWidget {
  const BudgetsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No budgets yet. Tap + to create one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
