import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants

const _errorSubject = 'account';
const _saveLabel = 'Save';
const _saveWidth = double.infinity;

// MARK: - AccountFormFrame
class AccountFormFrame extends StatelessWidget {
  const AccountFormFrame({
    super.key,
    required this.title,
    required this.children,
    required this.error,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final LedgerError? error;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        ErrorSection(subject: _errorSubject, error: error),
      ],
    );
    final saveButton = SizedBox(
      width: _saveWidth,
      child: PrimaryButton(label: _saveLabel, onPressed: onSave),
    );

    return AppSheet(
      header: AppPickerHeader(title: title),
      body: fields,
      footer: saveButton,
      variant: AppSheetVariant.form,
    );
  }
}
