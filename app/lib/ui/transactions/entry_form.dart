import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:domain/domain.dart' show Entry;
import 'package:spendwise/ui/transactions/edit_entry_form.dart';
import 'package:spendwise/ui/transactions/entry_form_controller.dart';
import 'package:spendwise/ui/transactions/new_entry_form.dart';
import 'package:spendwise/ui/transactions/view_entry_form.dart';

/// Opens the entry form as a bottom sheet. Pass [entry] to open it
/// read-only, or omit it for a new entry. [sourceScope] prefills the source.
Future<void> showEntryFormSheet({
  required BuildContext context,
  required Ledger ledger,
  Entry? entry,
  String? sourceScope,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        EntryForm(ledger: ledger, entry: entry, sourceScope: sourceScope),
  );
}

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    required this.ledger,
    this.entry,
    this.sourceScope,
  });

  final Ledger ledger;
  final Entry? entry;
  final String? sourceScope;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late final controller = EntryFormController(
    ledger: widget.ledger,
    entry: widget.entry,
    sourceScope: widget.sourceScope,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return switch (controller.mode) {
          EntryFormMode.viewing => ViewEntryForm(controller: controller),
          EntryFormMode.editing => EditEntryForm(controller: controller),
          EntryFormMode.newEntry => NewEntryForm(controller: controller),
        };
      },
    );
  }
}
