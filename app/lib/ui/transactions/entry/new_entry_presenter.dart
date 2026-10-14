import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_step_handlers.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';

// MARK: - Presentation State
enum NewEntryPresentation { closed, opening, presented }

final newEntryPresentationProvider = StateProvider<NewEntryPresentation>(
  (ref) => NewEntryPresentation.closed,
);

// MARK: - Helpers
const newEntryFormKey = ValueKey('new-entry-form');

AppSheetPresentation _presentationForMode(ShellLayoutMode mode) =>
    switch (mode) {
      ShellLayoutMode.phone => AppSheetPresentation.phone,
      ShellLayoutMode.open => AppSheetPresentation.open,
      ShellLayoutMode.desktop => AppSheetPresentation.desktop,
    };

Future<void> openNewEntry({
  required BuildContext context,
  required WidgetRef ref,
  String? sourceId,
}) async {
  if (ref.read(newEntryPresentationProvider) != NewEntryPresentation.closed) {
    return;
  }
  ref.read(newEntryPresentationProvider.notifier).state =
      NewEntryPresentation.opening;
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
    final initial = _presentationForMode(ref.read(shellLayoutModeProvider));
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
    ref.read(newEntryPresentationProvider.notifier).state =
        NewEntryPresentation.presented;
    await showAppSheet<void>(
      context,
      presentation: initial,
      presentationResolver: (routeContext) {
        final mode = ShellLayoutModeScope.maybeOf(routeContext);
        if (mode == null) return initial;
        return _presentationForMode(mode);
      },
      builder: (_) => const EntryForm(key: newEntryFormKey),
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
    ref.read(newEntryPresentationProvider.notifier).state =
        NewEntryPresentation.closed;
  }
}
