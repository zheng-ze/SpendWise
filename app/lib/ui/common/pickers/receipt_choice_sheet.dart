import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
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
  return showAppSheet<ReceiptChoice>(
    context,
    presentation: presentation(context),
    presentationResolver: presentation,
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
        const _ReceiptChoiceRow(
          label: _scanLabel,
          icon: Icons.camera_alt_outlined,
          choice: ReceiptChoice.scan,
        ),
        const _ReceiptChoiceRow(
          label: _photoLabel,
          icon: Icons.image_outlined,
          choice: ReceiptChoice.photo,
        ),
      ],
    );
  }
}

class _ReceiptChoiceRow extends StatelessWidget {
  const _ReceiptChoiceRow({
    required this.label,
    required this.icon,
    required this.choice,
  });

  final String label;
  final IconData icon;
  final ReceiptChoice choice;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).pop(choice),
      leading: Icon(icon),
      title: Text(label),
    );
  }
}
