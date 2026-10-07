import 'package:flutter/material.dart';

class TransactionsEmptyState extends StatelessWidget {
  const TransactionsEmptyState({super.key});

  static const _emptyIconSize = 48.0;
  static const _messageGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: _emptyIconSize, color: secondary),
          const SizedBox(height: _messageGap),
          Text('No transactions', style: TextStyle(color: secondary)),
        ],
      ),
    );
  }
}
