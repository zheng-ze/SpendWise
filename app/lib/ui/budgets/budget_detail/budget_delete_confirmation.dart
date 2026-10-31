import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_confirmation.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _deleteBodyText =
    'Your entries stay as they are. Only the limit is removed.';

const _deleteCancelLabel = 'Cancel';

const _deleteConfirmLabel = 'Delete';

// MARK: - Dialog

Future<bool> showBudgetDeleteConfirmation(
  BuildContext context, {
  required String title,
}) async {
  ModalRoute<bool>? dialogRoute;
  final confirmed = await showShellConfirmation<bool>(
    context,
    builder: (context) {
      dialogRoute ??= ModalRoute.of<bool>(context);
      return AlertDialog(
        title: Text('Delete the $title budget?'),
        content: const Text(_deleteBodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(_deleteCancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: context.colors.onAction,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(_deleteConfirmLabel),
          ),
        ],
      );
    },
  );
  await dialogRoute?.completed;
  return confirmed ?? false;
}
