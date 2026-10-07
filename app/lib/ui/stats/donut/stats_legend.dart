import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/helpers/slices.dart';

const _iconSize = 34.0;
const _dividerIndent = _iconSize + 32;

class StatsLegend extends StatelessWidget {
  const StatsLegend({
    super.key,
    required this.slices,
    required this.onTapCategory,
  });

  final List<Slice> slices;
  final void Function(String mainID) onTapCategory;

  static const _dividerHeight = 1.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < slices.length; index++) ...[
          if (index > 0)
            const Divider(height: _dividerHeight, indent: _dividerIndent),
          _LegendRow(
            slice: slices[index],
            onTap: slices[index].isNavigable
                ? () => onTapCategory(slices[index].bucketID!)
                : null,
          ),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, this.onTap});

  final Slice slice;
  final VoidCallback? onTap;

  static const _rowPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const _iconGap = 12.0;
  static const _chevronBoxWidth = 24.0;
  static const _chevronSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = AmountStyle.of(context);
    final percent = formatPercent(slice.fraction.toDouble());

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: _rowPadding,
        child: Row(
          children: [
            CategoryIcon(
              symbolName: slice.symbolName,
              color: slice.color,
              size: _iconSize,
            ),
            const SizedBox(width: _iconGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slice.name, style: theme.textTheme.bodyLarge),
                  Text(
                    percent,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(slice.amount, symbol: false),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: style.color,
              ),
            ),
            SizedBox(
              width: _chevronBoxWidth,
              child: onTap == null
                  ? null
                  : const Icon(Icons.chevron_right, size: _chevronSize),
            ),
          ],
        ),
      ),
    );
  }
}
