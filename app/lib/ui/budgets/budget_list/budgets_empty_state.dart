import 'package:flutter/material.dart';

// MARK: - Empty State

class BudgetsEmptyState extends StatelessWidget {
  const BudgetsEmptyState({super.key});

  static const _verticalPadding = 48.0;
  static const _iconSize = 48.0;
  static const _contentGap = 12.0;
  static const _emptyMessage = 'No budgets yet. Tap + to create one.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.savings_outlined,
              size: _iconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: _contentGap),
            Text(
              _emptyMessage,
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
