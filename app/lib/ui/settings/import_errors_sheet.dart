import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _sheetTitle = "Couldn't import";
const _listHorizontalInset = 20.0;
const _listTopInset = 8.0;
const _listBottomInset = 20.0;
const _listPadding = EdgeInsets.fromLTRB(
  _listHorizontalInset,
  _listTopInset,
  _listHorizontalInset,
  _listBottomInset,
);
const _messageGap = 12.0;

// MARK: - Show

Future<void> showImportErrorsSheet(
  BuildContext context, {
  required List<String> messages,
}) {
  return showAppSheet<void>(
    context,
    presentation: shellSheetPresentation(context),
    presentationResolver: shellSheetPresentation,
    builder: (_) => ImportErrorsSheet(messages: messages),
  );
}

// MARK: - Sheet

class ImportErrorsSheet extends StatelessWidget {
  const ImportErrorsSheet({super.key, required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      shrinkWrap: true,
      padding: _listPadding,
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: _messageGap),
      itemBuilder: (_, index) => _ImportErrorMessage(messages[index]),
    );

    return AppSheet(
      header: const AppPickerHeader(title: _sheetTitle),
      body: list,
    );
  }
}

class _ImportErrorMessage extends StatelessWidget {
  const _ImportErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: context.text.body.copyWith(color: context.colors.text),
    );
  }
}
