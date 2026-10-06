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
        constraints: const BoxConstraints(maxWidth: 440),
        child: _DeleteDialog(itemName: itemName),
      ),
    ),
  );

  return confirmed ?? false;
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.itemName});

  final String itemName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.control),
      ),
      child: IntrinsicWidth(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DeleteTitle(itemName: itemName),
              const SizedBox(height: 14),
              const _DeleteActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteTitle extends StatelessWidget {
  const _DeleteTitle({required this.itemName});

  final String itemName;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Delete $itemName?',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}

class _DeleteActions extends StatelessWidget {
  const _DeleteActions();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: 18,
      overflowSpacing: 8,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onAction,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
