import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_confirmation.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _cancelLabel = 'Cancel';

const _defaultConfirmLabel = 'Delete';

// MARK: - Dialog

Future<bool> showDestructiveConfirmation(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = _defaultConfirmLabel,
}) async {
  ModalRoute<bool>? dialogRoute;
  final confirmed = await showShellConfirmation<bool>(
    context,
    builder: (context) {
      dialogRoute ??= ModalRoute.of<bool>(context);
      return _DestructiveDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
      );
    },
  );
  await dialogRoute?.completed;
  return confirmed ?? false;
}

// MARK: - DestructiveDialog

class _DestructiveDialog extends StatelessWidget {
  const _DestructiveDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;

  final String body;

  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final cancel = TextButton(
      onPressed: () => navigator.pop(false),
      child: const Text(_cancelLabel),
    );
    final confirmStyle = FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.error,
      foregroundColor: context.colors.onAction,
    );
    final confirm = FilledButton(
      style: confirmStyle,
      onPressed: () => navigator.pop(true),
      child: Text(confirmLabel),
    );

    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [cancel, confirm],
    );
  }
}
