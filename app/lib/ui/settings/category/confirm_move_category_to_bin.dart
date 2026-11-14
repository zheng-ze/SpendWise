import 'package:flutter/widgets.dart';

import 'package:spendwise/ui/common/feedback/destructive_confirmation.dart';

// MARK: - Constants
const _body =
    'Entries keep their category. You can restore it from the recycle bin.';
const _confirmLabel = 'Move';

// MARK: - Confirmation
Future<bool> confirmMoveCategoryToBin(BuildContext context, String name) {
  return showDestructiveConfirmation(
    context,
    title: 'Move $name to the recycle bin?',
    body: _body,
    confirmLabel: _confirmLabel,
  );
}
