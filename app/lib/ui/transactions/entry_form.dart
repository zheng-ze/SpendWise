import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/transactions/edit_entry_form.dart';
import 'package:spendwise/ui/transactions/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/new_entry_form.dart';
import 'package:spendwise/ui/transactions/view_entry_form.dart';

/// Opens the entry form as a bottom sheet. Pass [entryId] to open an
/// existing entry read-only, or omit it for a new entry.
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

class EntryForm extends ConsumerWidget {
  const EntryForm({super.key, this.entryId});

  final String? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(entryFormViewModelProvider(entryId));
    final viewModel = ref.read(entryFormViewModelProvider(entryId).notifier);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (state) {
        if (state.dismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
        }
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
}
