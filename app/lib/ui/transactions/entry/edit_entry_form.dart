import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/form_scaffold.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';

// MARK: - EditEntryForm
class EditEntryForm extends StatelessWidget {
  const EditEntryForm({
    super.key,
    required this.viewModel,
    required this.state,
  });

  final EntryFormViewModel viewModel;
  final EntryFormViewState state;

  @override
  Widget build(BuildContext context) {
    final content = FormScaffold(
      title: 'Edit Entry',
      canSave: state.canSave,
      onSave: viewModel.save,
      error: ErrorSection(subject: 'entry', error: state.error),
      child: EntryFields(
        viewModel: viewModel,
        state: state,
        readOnly: false,
        showDelete: true,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) viewModel.revertToPersisted();
      },
      child: content,
    );
  }
}
