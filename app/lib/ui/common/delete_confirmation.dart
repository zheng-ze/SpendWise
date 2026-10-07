import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

Future<bool> showDeleteConfirmation(
  BuildContext context, {
  required String itemName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
        child: _DeleteDialog(itemName: itemName),
      ),
    ),
  );

  return confirmed ?? false;
}

const _dialogMaxWidth = 440.0;

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.itemName});

  static const _cornerRadius = 16.0;

  static const _contentGap = 14.0;

  static const _contentPadding = 16.0;

  final String itemName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cornerRadius),
      side: BorderSide(color: colors.control),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeleteTitle(itemName: itemName),
        const SizedBox(height: _contentGap),
        const _DeleteActions(),
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.all(_contentPadding),
      child: content,
    );
    return Dialog(
      backgroundColor: colors.raised,
      shape: shape,
      child: IntrinsicWidth(child: body),
    );
  }
}

class _DeleteTitle extends StatelessWidget {
  const _DeleteTitle({required this.itemName});

  static const _titleFontSize = 18.0;

  final String itemName;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Delete $itemName?',
      style: const TextStyle(
        fontSize: _titleFontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DeleteActions extends StatelessWidget {
  const _DeleteActions();

  static const _actionSpacing = 18.0;

  static const _actionOverflowSpacing = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cancel = TextButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: const Text('Cancel'),
    );
    final confirmStyle = FilledButton.styleFrom(
      backgroundColor: colors.error,
      foregroundColor: colors.onAction,
    );
    final confirm = FilledButton(
      style: confirmStyle,
      onPressed: () => Navigator.of(context).pop(true),
      child: const Text('Delete'),
    );
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: _actionSpacing,
      overflowSpacing: _actionOverflowSpacing,
      children: [cancel, confirm],
    );
  }
}
