import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_form.dart';

const _loadErrorMessage = "Couldn't load the entry form";

const _retryLabel = 'Retry';

void _scheduleDismiss(BuildContext context, VoidCallback? onDismiss) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (onDismiss != null) return onDismiss();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  });
}

// MARK: - EntryForm
class EntryForm extends ConsumerWidget {
  const EntryForm({super.key, this.onDismiss, this.onRetry});

  final VoidCallback? onDismiss;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(entryFormViewModelProvider(null));
    final state = async.isLoading || async.hasError ? null : async.value;
    if (state == null) {
      final failed = async.hasError && !async.isLoading;
      const loadAlert = SheetAlertData(
        message: _loadErrorMessage,
        severity: SheetAlertSeverity.error,
        actionLabel: _retryLabel,
      );
      return NewEntryLoadingForm(
        alert: failed ? loadAlert : null,
        onAlertAction: failed ? onRetry : null,
      );
    }
    if (state.dismissed) _scheduleDismiss(context, onDismiss);
    final saveError = state.error;
    final saveAlert = saveError == null
        ? null
        : SheetAlertData(
            message: entrySaveErrorMessage(saveError),
            severity: SheetAlertSeverity.error,
          );
    return NewEntryForm(
      formKey: null,
      viewModel: ref.read(entryFormViewModelProvider(null).notifier),
      state: state,
      display: ref.watch(entryFormDisplayProvider(null)),
      alert: saveAlert,
    );
  }
}
