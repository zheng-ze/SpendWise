import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

// MARK: - Visual Constants

const _actionWidth = double.infinity;

const _loadingIndicatorSize = 36.0;

const _loadingBodySpacing = 24.0;

// MARK: - NewEntryForm
class NewEntryForm extends StatelessWidget {
  const NewEntryForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    required this.state,
    this.alert,
    this.onAlertAction,
  });

  final String? formKey;
  final EntryFormViewModel viewModel;
  final EntryFormViewState state;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      header: _NewEntryHeader(onCancel: viewModel.cancel),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReceiptScanStrip(formKey: formKey),
          EntryFields(viewModel: viewModel, state: state, readOnly: false),
          ErrorSection(subject: 'entry', error: state.error),
        ],
      ),
      footer: _NewEntrySaveFooter(
        canSave: state.canSave,
        onSave: viewModel.save,
      ),
      alert: alert,
      onAlertAction: onAlertAction,
    );
  }
}

// MARK: - NewEntryLoadingForm
class NewEntryLoadingForm extends StatelessWidget {
  const NewEntryLoadingForm({
    super.key,
    required this.onCancel,
    this.alert,
    this.onAlertAction,
  });

  final VoidCallback? onCancel;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  static Future<void> _disabledSave() async {}

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      header: _NewEntryHeader(onCancel: onCancel),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _loadingBodySpacing),
          Center(
            child: SizedBox(
              width: _loadingIndicatorSize,
              height: _loadingIndicatorSize,
              child: CircularProgressIndicator(),
            ),
          ),
          SizedBox(height: _loadingBodySpacing),
        ],
      ),
      footer: const _NewEntrySaveFooter(canSave: false, onSave: _disabledSave),
      alert: alert,
      onAlertAction: onAlertAction,
    );
  }
}

// MARK: - NewEntryHeader
class _NewEntryHeader extends StatelessWidget {
  const _NewEntryHeader({required this.onCancel});

  final VoidCallback? onCancel;

  static const _titleSpacing = 8.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Add entry',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: _titleSpacing),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

// MARK: - NewEntrySaveFooter
class _NewEntrySaveFooter extends StatelessWidget {
  const _NewEntrySaveFooter({required this.canSave, required this.onSave});

  final bool canSave;
  final Future<void> Function() onSave;

  static const _saveTopSpacing = 4.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _saveTopSpacing),
      child: SizedBox(
        width: _actionWidth,
        child: FilledButton(
          onPressed: canSave ? onSave : null,
          child: const Text('Save'),
        ),
      ),
    );
  }
}
