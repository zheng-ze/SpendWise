import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Visual Constants

const _topSpacing = 12.0;

const _actionMinHeight = 48.0;

const _labelSize = 12.0;

const _labelWeight = FontWeight.w500;

// MARK: - Copy

const _deleteLabel = 'Delete entry';

// MARK: - EditEntryDeleteAction
class EditEntryDeleteAction extends StatelessWidget {
  const EditEntryDeleteAction({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: context.colors.error,
      minimumSize: const Size.fromHeight(_actionMinHeight),
      textStyle: const TextStyle(
        fontSize: _labelSize,
        fontWeight: _labelWeight,
      ),
    );
    final action = TextButton(
      key: const ValueKey('edit-entry-delete'),
      style: style,
      onPressed: onDelete,
      child: const Text(_deleteLabel),
    );

    return Padding(
      padding: const EdgeInsets.only(top: _topSpacing),
      child: action,
    );
  }
}
