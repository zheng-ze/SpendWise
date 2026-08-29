import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/transactions/entry/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

/// Form for a brand-new entry, including the optional recurrence picker.
class NewEntryForm extends StatelessWidget {
  const NewEntryForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    required this.state,
  });

  final String? formKey;
  final EntryFormViewModel viewModel;
  final EntryFormViewState state;

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'New Entry',
      canSave: state.canSave,
      onSave: viewModel.save,
      error: ErrorSection(subject: 'entry', error: state.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReceiptScanStrip(formKey: formKey),
          EntryFields(viewModel: viewModel, state: state, readOnly: false),
        ],
      ),
    );
  }
}
