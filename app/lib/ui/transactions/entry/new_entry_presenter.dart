import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_step_handlers.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';

bool _newEntryOpen = false;

// MARK: - Helpers
Future<void> openNewEntry({
  required BuildContext context,
  required WidgetRef ref,
  String? sourceId,
}) async {
  if (_newEntryOpen) return;
  _newEntryOpen = true;
  ProviderSubscription<AsyncValue<EntryFormViewState>>? subscription;
  try {
    ref.invalidate(entryFormViewModelProvider(null));
    ref.invalidate(receiptEntryCoordinatorProvider(null));
    await ref.read(entryFormViewModelProvider(null).future);
    if (!context.mounted) return;
    if (sourceId != null) {
      ref
          .read(entryFormViewModelProvider(null).notifier)
          .prefillSource(sourceId);
    }
    final presentation =
        ref.read(shellLayoutModeProvider) == ShellLayoutMode.desktop
        ? AppSheetPresentation.desktop
        : AppSheetPresentation.phone;
    subscription = ref.listenManual(entryFormViewModelProvider(null), (
      previous,
      next,
    ) {
      final step = next.value?.step;
      if (step == null) return;
      if (!context.mounted) return;
      dispatchEntryFormStep(context, ref, null, step, useRootNavigator: true);
      ref.read(entryFormViewModelProvider(null).notifier).clearStep();
    });
    await showAppSheet<void>(
      context,
      presentation: presentation,
      builder: (_) => const EntryForm(),
    );
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'spendwise',
        context: ErrorDescription('while opening a new entry'),
      ),
    );
  } finally {
    subscription?.close();
    _newEntryOpen = false;
  }
}
