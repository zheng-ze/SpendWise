import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/pickers/category_picker.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/common/pickers/source_picker.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/transactions/document_crop/document_crop_screen.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart'
    show EntryFormKind;
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

// MARK: - Constants
const _datePickerFirstYear = 2000;

const _datePickerLastYear = 2100;

// MARK: - Dispatch
void dispatchEntryFormStep(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  TransactionsStep step, {
  bool useRootNavigator = false,
}) {
  final form = ref.read(entryFormViewModelProvider(formKey).notifier);
  switch (step) {
    case PickSourceRequested():
      _pickSource(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
      );
    case PickDestinationRequested():
      _pickDestination(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
      );
    case PickCategoryRequested():
      _pickCategory(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
      );
    case PickRecurrenceRequested():
      _pickRecurrence(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
      );
    case PickDateRequested():
      _pickDate(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
      );
    case PickEndDateRequested():
      _pickEndDate(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
      );
    case DocumentCropRequested(:final imageBytes):
      _pushDocumentCrop(
        context,
        form,
        imageBytes,
        useRootNavigator: useRootNavigator,
      );
    case EntryFormRequested():
      break;
  }
}

// MARK: - Source Pickers
Future<void> _pickSource(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
}) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final outcome = await showSourcePickerSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    title: formState?.kind == EntryFormKind.transfer ? 'From' : 'Account',
    state: ledger.state,
    selectedId: formState?.sourceId,
  );
  if (!context.mounted) return;
  if (outcome == null) return;
  form.applyPickedSource(_idFromOutcome(outcome));
}

Future<void> _pickDestination(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
}) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final outcome = await showSourcePickerSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    title: 'To',
    state: ledger.state,
    selectedId: formState?.destinationId,
  );
  if (!context.mounted) return;
  if (outcome == null) return;
  form.applyPickedDestination(_idFromOutcome(outcome));
}

// MARK: - Category/Recurrence Pickers
Future<void> _pickCategory(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
}) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final categoryKind = formState?.kind == EntryFormKind.income
      ? CategoryKind.income
      : CategoryKind.expense;
  final outcome = await showCategoryPickerSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    state: ledger.state,
    kind: categoryKind,
    selectedId: formState?.categoryId,
  );
  if (!context.mounted) return;
  if (outcome == null) return;
  form.applyPickedCategory(_idFromOutcome(outcome));
}

Future<void> _pickRecurrence(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
}) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final chosen = await showRecurrencePickerSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    selected: formState?.recurrence,
  );
  if (!context.mounted) return;
  form.applyPickedRecurrence(chosen);
}

String? _idFromOutcome(PickerOutcome outcome) => switch (outcome) {
  PickerChose(:final id) => id,
  PickerCleared() => null,
};

// MARK: - Date Pickers
Future<void> _pickDate(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
}) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final picked = await showDatePicker(
    context: context,
    useRootNavigator: useRootNavigator,
    initialDate: formState?.date ?? DateTime.now(),
    firstDate: DateTime.utc(_datePickerFirstYear),
    lastDate: DateTime.utc(_datePickerLastYear),
  );
  if (!context.mounted) return;
  if (picked == null) return;
  form.applyPickedDate(DateTime.utc(picked.year, picked.month, picked.day));
}

Future<void> _pickEndDate(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
}) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final initial = formState?.endDate ?? formState?.date ?? DateTime.now();
  final picked = await showDatePicker(
    context: context,
    useRootNavigator: useRootNavigator,
    initialDate: initial,
    firstDate: formState?.date ?? DateTime.utc(_datePickerFirstYear),
    lastDate: DateTime.utc(_datePickerLastYear),
  );
  if (!context.mounted) return;
  if (picked == null) return;
  form.applyPickedEndDate(DateTime.utc(picked.year, picked.month, picked.day));
}

// MARK: - Document Cropping
Future<void> _pushDocumentCrop(
  BuildContext context,
  EntryFormNotifier form,
  Uint8List imageBytes, {
  bool useRootNavigator = false,
}) async {
  final cropped = await Navigator.of(context, rootNavigator: useRootNavigator)
      .push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => DocumentCropScreen(imageBytes: imageBytes),
        ),
      );
  if (!context.mounted) return;
  if (cropped == null) return;
  form.applyCroppedDocument(cropped);
}
