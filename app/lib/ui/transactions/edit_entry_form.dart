import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/transactions/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';

/// Editable form for an existing entry. Dismissing without saving (barrier
/// tap, back gesture) reverts [controller] to the persisted values instead
/// of closing the sheet.
class EditEntryForm extends StatelessWidget {
  const EditEntryForm({super.key, required this.controller});

  final EntryFormController controller;

  @override
  Widget build(BuildContext context) {
    final content = FormScaffold(
      title: 'Edit Entry',
      canSave: controller.canSave,
      onSave: () => controller.save(context),
      error: ErrorSection(subject: 'entry', error: controller.error),
      child: EntryFields(
        controller: controller,
        readOnly: false,
        showDelete: true,
      ),
    );

    // Editing an existing entry reverts instead of dismissing, so any pop
    // attempt (barrier tap, back gesture) intercepts and reverts instead of
    // closing the sheet.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.revertToPersisted();
      },
      child: content,
    );
  }
}
