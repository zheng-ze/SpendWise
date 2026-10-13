import 'package:flutter/material.dart';

import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _purgeDialogTitle = 'Delete permanently?';

const _purgeCancelLabel = 'Cancel';

const _purgeConfirmLabel = 'Delete';

// MARK: - Dialog

Future<bool> confirmBinPurge(BuildContext context, BinRow row) async {
  final purgeBody = row.kind == BinRowKind.entry
      ? '${row.name} leaves the bin for good and can no longer be restored.'
      : '${row.name} leaves the bin for good. Existing transactions keep '
            'the name but it can no longer be restored.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(_purgeDialogTitle),
      content: Text(purgeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(_purgeCancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: context.colors.onAction,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(_purgeConfirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
