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
const _compactPadding = 16.0;
const _openPadding = 20.0;
const _compactInset = 22.0;
const _openInset = 0.0;
const _dialogRadius = 16.0;
const _dialogBorderWidth = 1.0;
const _dialogElevation = 0.0;
const _openShadow = BoxShadow(
  color: Color(0x26000000),
  offset: Offset(0, 12),
  blurRadius: 40,
);
const _titleSize = 18.0;
const _titleWeight = FontWeight.w600;
const _bodySize = 12.0;
const _bodyHeight = 1.45;
const _actionSize = 12.0;
const _actionWeight = FontWeight.w600;
const _titleBodyGap = 6.0;
const _bodyActionsGap = 14.0;
const _actionsGap = 18.0;
const _actionsOverflowGap = 8.0;
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
    final open = ShellLayoutModeScope.maybeOf(context) == ShellLayoutMode.open;
    final isApple = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
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
      padding: EdgeInsets.all(open ? _openPadding : _compactPadding),
      child: IntrinsicWidth(child: content),
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_dialogRadius),
      side: BorderSide(color: colors.control, width: _dialogBorderWidth),
    );
    final dialog = Dialog(
      backgroundColor: colors.raised,
      elevation: _dialogElevation,
      insetPadding: EdgeInsets.all(open ? _openInset : _compactInset),
      shape: shape,
      semanticsRole: SemanticsRole.alertDialog,
      child: semantic,
    );
    if (!open) return dialog;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_dialogRadius),
        boxShadow: const [_openShadow],
      ),
      child: dialog,
    );
  }
}
