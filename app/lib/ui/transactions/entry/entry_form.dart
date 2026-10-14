import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/transactions/entry/edit_entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_form.dart';
import 'package:spendwise/ui/transactions/entry/view_entry_form.dart';

// MARK: - Helpers
Future<void> showEntryFormSheet({
  required BuildContext context,
  String? entryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EntryForm(entryId: entryId),
  );
}

// MARK: - EntryForm
class EntryForm extends ConsumerWidget {
  const EntryForm({super.key, this.entryId, this.onDismiss});

  final String? entryId;

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(entryFormViewModelProvider(entryId));
    final viewModel = ref.read(entryFormViewModelProvider(entryId).notifier);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (state) {
        if (state.dismissed) _scheduleDismiss(context);
        return switch (state.mode) {
          EntryFormMode.viewing => ViewEntryForm(
            viewModel: viewModel,
            state: state,
          ),
          EntryFormMode.editing => EditEntryForm(
            viewModel: viewModel,
            state: state,
          ),
          EntryFormMode.newEntry => NewEntryForm(
            formKey: entryId,
            viewModel: viewModel,
            state: state,
          ),
        };
      },
    );
  }

  void _scheduleDismiss(BuildContext context) {
    final onDismiss = this.onDismiss;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (onDismiss != null) return onDismiss();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }
}
