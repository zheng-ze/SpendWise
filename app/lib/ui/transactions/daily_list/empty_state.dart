import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - TransactionsEmptyState
class TransactionsEmptyState extends StatelessWidget {
  const TransactionsEmptyState({super.key});

  static const _emptyIcon = Icons.inbox_outlined;
  static const _emptyMessage = 'No transactions';
  static const _emptyIconSize = 32.0;
  static const _messageGap = 10.0;
  static const _iconTileSize = 48.0;
  static const _iconTileRadius = 14.0;
  static const _messageFontSize = 14.0;
  static const _messageFontWeight = FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconTile = Container(
      width: _iconTileSize,
      height: _iconTileSize,
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(_iconTileRadius),
      ),
      alignment: Alignment.center,
      child: Icon(_emptyIcon, size: _emptyIconSize, color: colors.subtext),
    );
    final message = Text(
      _emptyMessage,
      style: TextStyle(
        color: colors.subtext,
        fontSize: _messageFontSize,
        fontWeight: _messageFontWeight,
      ),
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconTile,
          const SizedBox(height: _messageGap),
          message,
        ],
      ),
    );
  }
}
