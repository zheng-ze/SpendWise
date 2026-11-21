import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';

// MARK: - Visual Constants

const _topSpacing = 12.0;

// MARK: - Copy

const _deleteLabel = 'Delete entry';

// MARK: - EditEntryDeleteAction
class EditEntryDeleteAction extends StatelessWidget {
  const EditEntryDeleteAction({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final action = SecondaryButton(
      key: const ValueKey('edit-entry-delete'),
      label: _deleteLabel,
      destructive: true,
      onPressed: onDelete,
    );

    return Padding(
      padding: const EdgeInsets.only(top: _topSpacing),
      child: action,
    );
  }
}
