import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_confirmation.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _cancelLabel = 'Cancel';
const _defaultConfirmLabel = 'Delete';
const _dialogMaxWidth = 308.0;
const _dialogPadding = 20.0;
const _dialogRadius = 16.0;
const _dialogBorderWidth = 1.0;
const _dialogElevation = 0.0;
const _dialogInset = 22.0;
const _titleSize = 18.0;
const _titleWeight = FontWeight.w600;
const _bodySize = 12.0;
const _bodyHeight = 1.45;
const _actionSize = 12.0;
const _actionWeight = FontWeight.w600;
const _titleBodyGap = 6.0;
const _bodyActionsGap = 14.0;
const _actionsGap = 18.0;
const _confirmRadius = 8.0;
const _confirmPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 7);

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
    final colors = context.colors;
    final navigator = Navigator.of(context);
    const actionText = TextStyle(
      fontSize: _actionSize,
      fontWeight: _actionWeight,
    );
    final titleStyle = TextStyle(
      color: colors.text,
      fontSize: _titleSize,
      fontWeight: _titleWeight,
    );
    final bodyStyle = TextStyle(
      color: colors.subtext,
      fontSize: _bodySize,
      height: _bodyHeight,
    );
    final cancel = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: colors.action,
        textStyle: actionText,
      ),
      onPressed: () => navigator.pop(false),
      child: const Text(_cancelLabel),
    );
    final confirm = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: colors.error,
        foregroundColor: colors.onAction,
        textStyle: actionText,
        padding: _confirmPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_confirmRadius),
        ),
      ),
      onPressed: () => navigator.pop(true),
      child: Text(confirmLabel),
    );
    final actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: _actionsGap,
      children: [cancel, confirm],
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: _titleBodyGap),
        Text(body, style: bodyStyle),
        const SizedBox(height: _bodyActionsGap),
        actions,
      ],
    );

    return Dialog(
      backgroundColor: colors.raised,
      elevation: _dialogElevation,
      insetPadding: const EdgeInsets.all(_dialogInset),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_dialogRadius),
        side: BorderSide(color: colors.control, width: _dialogBorderWidth),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(_dialogPadding),
          child: content,
        ),
      ),
    );
  }
}
