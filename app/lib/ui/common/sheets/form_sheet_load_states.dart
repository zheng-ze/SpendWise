import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

// MARK: - Constants
const _loadingLabel = 'Loading';
const _loadingGap = 12.0;
const _loadingPadding = EdgeInsets.symmetric(vertical: 32);

// MARK: - FormSheetLoading
class FormSheetLoading extends StatelessWidget {
  const FormSheetLoading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const body = Padding(
      padding: _loadingPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: _loadingGap),
          Text(_loadingLabel),
        ],
      ),
    );

    return AppSheet(
      header: AppPickerHeader(title: title),
      body: const Center(child: body),
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}

// MARK: - FormSheetLoadError
class FormSheetLoadError extends StatelessWidget {
  const FormSheetLoadError({
    super.key,
    required this.title,
    required this.message,
    required this.error,
    required this.footer,
  });

  final String title;
  final String message;
  final Object? error;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final alert = SheetAlertData(
      message: '$message\n$error',
      severity: SheetAlertSeverity.error,
    );

    return AppSheet(
      header: AppPickerHeader(title: title),
      body: const SizedBox.shrink(),
      footer: footer,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}
