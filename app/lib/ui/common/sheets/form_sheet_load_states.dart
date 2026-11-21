import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

// MARK: - Constants
const _loadingLabel = 'Loading';
const _loadingGap = 12.0;
const _loadingPadding = EdgeInsets.symmetric(vertical: 32);
const _retryLabel = 'Try again';
const _footerWidth = double.infinity;

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
      variant: AppSheetVariant.form,
    );
  }
}

// MARK: - FormSheetAsyncHost
class FormSheetAsyncHost<T> extends StatelessWidget {
  const FormSheetAsyncHost({
    super.key,
    required this.state,
    required this.title,
    required this.loadErrorMessage,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> state;
  final String title;
  final String loadErrorMessage;
  final VoidCallback onRetry;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    final value = state.value;
    if (value != null) return builder(value);
    final error = state.error;
    if (error == null) return FormSheetLoading(title: title);
    final retry = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(label: _retryLabel, onPressed: onRetry),
    );
    return FormSheetLoadError(
      title: title,
      message: loadErrorMessage,
      error: error,
      footer: retry,
    );
  }
}
