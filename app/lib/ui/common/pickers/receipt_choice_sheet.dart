import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/choice_tile.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _titleLabel = 'Add receipt';

const _hintLabel = 'Scanning fills in a draft. You check it before saving.';

const _scanLabel = 'Scan receipt';

const _photoLabel = 'Choose photo';

const _hintSize = 12.0;

const _hintPadding = EdgeInsets.fromLTRB(16, 2, 16, 8);

enum ReceiptChoice { scan, photo }

Future<ReceiptChoice?> showReceiptChoiceSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) presentation,
  void Function(AppSheetRoute<ReceiptChoice>)? onRouteCreated,
}) {
  final sheet = AppPickerSheet(
    title: _titleLabel,
    body: const _ReceiptChoiceBody(),
  );
  return showPickerAppSheet<ReceiptChoice>(
    context,
    presentation: presentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => sheet,
  );
}

class _ReceiptChoiceBody extends StatelessWidget {
  const _ReceiptChoiceBody();

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final hintStyle = baseStyle.copyWith(
      fontSize: _hintSize,
      color: context.colors.subtext,
    );
    final hint = Padding(
      padding: _hintPadding,
      child: Text(_hintLabel, style: hintStyle),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hint,
        const ChoiceTile<ReceiptChoice>(
          label: _scanLabel,
          leading: Icons.camera_alt_outlined,
          value: ReceiptChoice.scan,
        ),
        const ChoiceTile<ReceiptChoice>(
          label: _photoLabel,
          leading: Icons.image_outlined,
          value: ReceiptChoice.photo,
        ),
      ],
    );
  }
}
