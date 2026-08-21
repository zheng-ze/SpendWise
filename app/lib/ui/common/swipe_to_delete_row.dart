import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:spendwise/ui/common/delete_confirmation.dart';

/// A row deletable by swiping left or by the equivalent semantic action, for
/// a screen reader user who can't swipe. Asks the user to confirm, and calls
/// [onDeleted] only if they agree.
class SwipeToDeleteRow extends StatelessWidget {
  const SwipeToDeleteRow({
    super.key,
    required this.itemKey,
    required this.itemName,
    required this.onDeleted,
    required this.child,
  });

  final Key itemKey;
  final String itemName;
  final VoidCallback onDeleted;
  final Widget child;

  Future<bool> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmation(context, itemName: itemName);
    if (confirmed) onDeleted();
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Delete $itemName'): () =>
            _confirmAndDelete(context),
      },
      child: Dismissible(
        key: itemKey,
        direction: DismissDirection.endToStart,
        background: Container(
          color: Theme.of(context).colorScheme.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (_) => _confirmAndDelete(context),
        child: child,
      ),
    );
  }
}
