import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:spendwise/ui/common/feedback/delete_confirmation.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - SwipeRow
class SwipeRow extends StatelessWidget {
  const SwipeRow({
    super.key,
    required this.itemKey,
    required this.itemName,
    required this.onDeleted,
    this.onEdit,
    required this.child,
  });

  final Key itemKey;
  final String itemName;
  final VoidCallback onDeleted;
  final VoidCallback? onEdit;
  final Widget child;

  static const _editBackgroundAlignment = AlignmentDirectional.centerStart;
  static const _deleteBackgroundAlignment = AlignmentDirectional.centerEnd;
  static const _editIcon = Icons.edit_outlined;
  static const _deleteIcon = Icons.delete_outline;
  static const _deleteActionLabelPrefix = 'Delete';
  static const _editActionLabelPrefix = 'Edit';

  Future<bool> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmation(context, itemName: itemName);
    if (confirmed) onDeleted();
    return confirmed;
  }

  Future<bool> _confirmDismiss(
    BuildContext context,
    DismissDirection direction,
  ) async {
    final editCallback = onEdit;
    if (direction == DismissDirection.startToEnd && editCallback != null) {
      editCallback();
      return false;
    }
    return _confirmAndDelete(context);
  }

  @override
  Widget build(BuildContext context) {
    final editCallback = onEdit;
    final editSemanticsActions = editCallback == null
        ? null
        : <CustomSemanticsAction, VoidCallback>{
            CustomSemanticsAction(label: '$_editActionLabelPrefix $itemName'):
                editCallback,
          };
    final deleteBackground = _ActionBackground(
      color: Theme.of(context).colorScheme.error,
      alignment: _deleteBackgroundAlignment,
      icon: _deleteIcon,
    );
    final editBackground = _ActionBackground(
      color: context.colors.action,
      alignment: _editBackgroundAlignment,
      icon: _editIcon,
    );
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(
          label: '$_deleteActionLabelPrefix $itemName',
        ): () =>
            _confirmAndDelete(context),
        ...?editSemanticsActions,
      },
      child: Dismissible(
        key: itemKey,
        direction: onEdit == null
            ? DismissDirection.endToStart
            : DismissDirection.horizontal,
        background: onEdit == null ? deleteBackground : editBackground,
        secondaryBackground: onEdit == null ? null : deleteBackground,
        confirmDismiss: (direction) => _confirmDismiss(context, direction),
        child: child,
      ),
    );
  }
}

// MARK: - ActionBackground
class _ActionBackground extends StatelessWidget {
  const _ActionBackground({
    required this.color,
    required this.alignment,
    required this.icon,
  });

  final Color color;
  final AlignmentGeometry alignment;
  final IconData icon;

  static const _horizontalPadding = 20.0;
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
    child: Icon(icon, size: _iconSize, color: context.colors.onAction),
  );
}
