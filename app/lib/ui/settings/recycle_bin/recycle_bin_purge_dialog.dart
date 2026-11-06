import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/destructive_confirmation.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';

// MARK: - Constants

const _purgeDialogTitle = 'Delete permanently?';

// MARK: - Dialog

Future<bool> confirmBinPurge(BuildContext context, BinRow row) {
  final purgeBody = row.kind == BinRowKind.entry
      ? '${row.name} leaves the bin for good and can no longer be restored.'
      : '${row.name} leaves the bin for good. Existing transactions keep '
            'the name but it can no longer be restored.';
  return showDestructiveConfirmation(
    context,
    title: _purgeDialogTitle,
    body: purgeBody,
  );
}
