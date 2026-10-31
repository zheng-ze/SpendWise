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
      return _BudgetDeleteDialog(title: title);
    },
  );
  await dialogRoute?.completed;
  return confirmed ?? false;
}

// MARK: - BudgetDeleteDialog

class _BudgetDeleteDialog extends StatelessWidget {
  const _BudgetDeleteDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final cancel = TextButton(
      onPressed: () => navigator.pop(false),
      child: const Text(_deleteCancelLabel),
    );
    final confirmStyle = FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.error,
      foregroundColor: context.colors.onAction,
    );
    final confirm = FilledButton(
      style: confirmStyle,
      onPressed: () => navigator.pop(true),
      child: const Text(_deleteConfirmLabel),
    );

    return AlertDialog(
      title: Text('Delete the $title budget?'),
      content: const Text(_deleteBodyText),
      actions: [cancel, confirm],
    );
  }
}
