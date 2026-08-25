import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/transactions/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';
import 'package:spendwise/ui/transactions/receipt_scan_strip.dart';

/// Form for a brand-new entry, including the optional recurrence picker.
class NewEntryForm extends StatelessWidget {
  const NewEntryForm({super.key, required this.controller});

  final EntryFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'New Entry',
      canSave: controller.canSave,
      onSave: () => controller.save(context),
      error: ErrorSection(subject: 'entry', error: controller.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReceiptScanStrip(controller: controller),
          EntryFields(controller: controller, readOnly: false),
        ],
      ),
    );
  }
}
