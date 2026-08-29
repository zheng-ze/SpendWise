import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/format/amount_color.dart';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < slices.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: _dividerIndent),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AmountColors.of(theme);
    final percent = formatPercent(slice.fraction.toDouble());

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CategoryIcon(
              symbolName: slice.symbolName,
              color: slice.color,
              size: _iconSize,
            ),
            const SizedBox(width: 12),
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
              formatCurrency(slice.amount),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.neutral,
              ),
            ),
            SizedBox(
              width: 24,
              child: onTap == null
                  ? null
                  : const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
