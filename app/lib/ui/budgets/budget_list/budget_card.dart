import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/budgets/helpers/budget_spend.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_card_progress_bar.dart';

export 'package:spendwise/ui/budgets/budget_list/budgets_empty_state.dart';

// MARK: - Constants

const _emptyProgress = 0.0;
const _fullProgress = 1.0;

// MARK: - Card

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

  final bool isSubcategory;
  final VoidCallback? onTap;

  static const _subcategoryIndent = 32.0;
  static const _horizontalPadding = 16.0;
  static const _verticalPadding = 12.0;
  static const _headerGap = 6.0;
  static const _footerGap = 4.0;

  (String, Color) _categoryDisplay(LedgerState state) {
    final categoryID = budget.categoryID;
    if (categoryID == null) return ('Overall', colorHexFallback);

    final category = state.categories[categoryID];
    if (category == null) return ('(category deleted)', colorHexFallback);
    return (category.name, parseColorHex(category.colorHex));
  }

  @override
  Widget build(BuildContext context) {
    final (name, color) = _categoryDisplay(state);

    final limit = effectiveLimit(budget, month);
    final spend = budgetSpend(budget, month, items, state);
    final remaining = limit - spend;
    final overLimit = spend > limit;
    final percentOfLimit = limit == Decimal.zero
        ? (spend == Decimal.zero ? _emptyProgress : _fullProgress)
        : (spend / limit).toDouble();

    final header = _BudgetCardHeader(
      name: name,
      limit: limit,
      isSubcategory: isSubcategory,
    );
    final bar = BudgetCardProgressBar(
      percentOfLimit: percentOfLimit,
      color: overLimit
          ? AmountStyle.of(context, kind: AmountKind.expense).color
          : color,
    );
    final footer = _BudgetCardFooter(
      spend: spend,
      remaining: remaining,
      overLimit: overLimit,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isSubcategory ? _subcategoryIndent : _horizontalPadding,
          _verticalPadding,
          _horizontalPadding,
          _verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: _headerGap),
            bar,
            const SizedBox(height: _footerGap),
            footer,
          ],
        ),
      ),
    );
  }
}

// MARK: - Header

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
          formatMoney(limit),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// MARK: - Footer

class _BudgetCardFooter extends StatelessWidget {
  const _BudgetCardFooter({
    required this.spend,
    required this.remaining,
    required this.overLimit,
  });

  final Decimal spend;
  final Decimal remaining;
  final bool overLimit;

  static const _warningIconSize = 14.0;
  static const _warningIconGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expense = AmountStyle.of(context, kind: AmountKind.expense).color;
    final neutral = AmountStyle.of(context).color;

    return Row(
      children: [
        if (overLimit)
          Padding(
            padding: const EdgeInsets.only(right: _warningIconGap),
            child: Icon(
              Icons.warning_amber_rounded,
              size: _warningIconSize,
              color: expense,
            ),
          ),
        Text(
          formatMoney(spend, symbol: false),
          style: theme.textTheme.bodySmall?.copyWith(
            color: overLimit ? expense : neutral,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        Text(
          remaining < Decimal.zero
              ? '-${formatMoney(remaining.abs(), symbol: false)}'
              : formatMoney(remaining, symbol: false),
          style: theme.textTheme.bodySmall?.copyWith(
            color: overLimit ? expense : theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
