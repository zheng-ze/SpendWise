import 'package:flutter/material.dart';

@immutable
class ColumnTextItem {
  const ColumnTextItem({
    required this.caption,
    required this.value,
    this.valueColor,
  });

  final String caption;
  final String value;
  final Color? valueColor;
}

class ColumnText extends StatelessWidget {
  const ColumnText({super.key, required this.items});

  static const _captionValueGap = 2.0;

  final List<ColumnTextItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.caption,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: _captionValueGap),
                Text(
                  item.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: item.valueColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
