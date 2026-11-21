import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_confirmation.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _cancelLabel = 'Cancel';
const _defaultConfirmLabel = 'Delete';
const _dialogPadding = 16.0;
const _phoneInset = 22.0;
const _wideInset = 0.0;
const _dialogMaxWidth = 360.0;
const _dialogRadius = 14.0;
const _dialogBorderWidth = 1.0;
const _dialogElevation = 0.0;
const _transparent = Color(0x00000000);
const _titleBodyGap = 6.0;
const _bodyActionsGap = 14.0;
const _actionsGap = 12.0;
const _actionsOverflowGap = 8.0;
const _actionRadius = 8.0;
const _actionMinSize = Size(48, 48);
const _actionPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

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
    final phone =
        ShellLayoutModeScope.maybeOf(context) == ShellLayoutMode.phone;
    final isApple = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final navigator = Navigator.of(context);
    final actionText = context.text.body.copyWith(
      fontWeight: SpendWiseText.semibold,
    );
    final titleStyle = context.text.title.copyWith(
      color: colors.text,
      fontWeight: SpendWiseText.semibold,
    );
    final bodyStyle = context.text.body.copyWith(color: colors.subtext);
    final actionShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_actionRadius),
    );
    final cancel = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: colors.action,
        textStyle: actionText,
        minimumSize: _actionMinSize,
        padding: _actionPadding,
        shape: actionShape,
      ),
      onPressed: () => navigator.pop(false),
      child: const Text(_cancelLabel),
    );
    final confirm = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: colors.error,
        foregroundColor: colors.onAction,
        textStyle: actionText,
        minimumSize: _actionMinSize,
        padding: _actionPadding,
        shape: actionShape,
      ),
      onPressed: () => navigator.pop(true),
      child: Text(confirmLabel),
    );
    final actions = OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: _actionsGap,
      overflowAlignment: OverflowBarAlignment.end,
      overflowSpacing: _actionsOverflowGap,
      children: [cancel, confirm],
    );
    final titleText = Text(title, style: titleStyle);
    final titleWidget = isApple
        ? Semantics(namesRoute: true, child: titleText)
        : titleText;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleWidget,
        const SizedBox(height: _titleBodyGap),
        Text(body, style: bodyStyle),
      ],
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(child: SingleChildScrollView(child: text)),
        const SizedBox(height: _bodyActionsGap),
        actions,
      ],
    );
    final padded = Padding(
      padding: const EdgeInsets.all(_dialogPadding),
      child: content,
    );
    final label = isApple
        ? null
        : MaterialLocalizations.of(context).alertDialogLabel;
    final semantic = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: !isApple,
      label: label,
      child: padded,
    );
    final radius = BorderRadius.circular(_dialogRadius);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: radius,
        border: Border.all(color: colors.control, width: _dialogBorderWidth),
      ),
      child: semantic,
    );
    final sized = SizedBox(width: _dialogMaxWidth, child: card);

    return Dialog(
      backgroundColor: _transparent,
      elevation: _dialogElevation,
      insetPadding: EdgeInsets.all(phone ? _phoneInset : _wideInset),
      shape: RoundedRectangleBorder(borderRadius: radius),
      semanticsRole: SemanticsRole.alertDialog,
      child: sized,
    );
  }
}
