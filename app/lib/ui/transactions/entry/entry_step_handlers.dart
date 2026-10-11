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
import 'package:spendwise/ui/transactions/entry/entry_form_logic.dart'
    show EntryFormKind;
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

const _datePickerFirstYear = 2000;

const _datePickerLastYear = 2100;

void dispatchEntryFormStep(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  TransactionsStep step,
) {
  switch (step) {
    case PickSourceRequested():
      pickEntrySource(context, ref, formKey);
    case PickDestinationRequested():
      pickEntryDestination(context, ref, formKey);
    case PickCategoryRequested():
      pickEntryCategory(context, ref, formKey);
    case PickRecurrenceRequested():
      pickEntryRecurrence(context, ref, formKey);
    case PickDateRequested():
      pickEntryDate(context, ref, formKey);
    case PickEndDateRequested():
      pickEntryEndDate(context, ref, formKey);
    case DocumentCropRequested(:final imageBytes):
      pushDocumentCrop(context, ref, formKey, imageBytes);
    case EntryFormRequested():
    case SourceEditRequested():
      break;
  }
}

Future<void> pickEntrySource(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final outcome = await showSourcePickerSheet(
    context: context,
    useRootNavigator: true,
    title: formState?.kind == EntryFormKind.transfer ? 'From' : 'Account',
    state: ledger.state,
    selectedId: formState?.sourceId,
  );
  if (!context.mounted) return;
  if (outcome == null) return;
  ref
      .read(entryFormViewModelProvider(formKey).notifier)
      .applyPickedSource(_idFromOutcome(outcome));
}

Future<void> pickEntryDestination(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final outcome = await showSourcePickerSheet(
    context: context,
    useRootNavigator: true,
    title: 'To',
    state: ledger.state,
    selectedId: formState?.destinationId,
  );
  if (!context.mounted) return;
  if (outcome == null) return;
  ref
      .read(entryFormViewModelProvider(formKey).notifier)
      .applyPickedDestination(_idFromOutcome(outcome));
}

Future<void> pickEntryCategory(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final categoryKind = formState?.kind == EntryFormKind.income
      ? CategoryKind.income
      : CategoryKind.expense;
  final outcome = await showCategoryPickerSheet(
    context: context,
    useRootNavigator: true,
    state: ledger.state,
    kind: categoryKind,
    selectedId: formState?.categoryId,
  );
  if (!context.mounted) return;
  if (outcome == null) return;
  ref
      .read(entryFormViewModelProvider(formKey).notifier)
      .applyPickedCategory(_idFromOutcome(outcome));
}

Future<void> pickEntryRecurrence(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final chosen = await showRecurrencePickerSheet(
    context: context,
    useRootNavigator: true,
    selected: formState?.recurrence,
  );
  if (!context.mounted) return;
  ref
      .read(entryFormViewModelProvider(formKey).notifier)
      .applyPickedRecurrence(chosen);
}

Future<void> pickEntryDate(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final picked = await showDatePicker(
    context: context,
    useRootNavigator: true,
    initialDate: formState?.date ?? DateTime.now(),
    firstDate: DateTime.utc(_datePickerFirstYear),
    lastDate: DateTime.utc(_datePickerLastYear),
  );
  if (!context.mounted) return;
  if (picked == null) return;
  ref
      .read(entryFormViewModelProvider(formKey).notifier)
      .applyPickedDate(DateTime.utc(picked.year, picked.month, picked.day));
}

Future<void> pickEntryEndDate(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final initial = formState?.endDate ?? formState?.date ?? DateTime.now();
  final picked = await showDatePicker(
    context: context,
    useRootNavigator: true,
    initialDate: initial,
    firstDate: formState?.date ?? DateTime.utc(_datePickerFirstYear),
    lastDate: DateTime.utc(_datePickerLastYear),
  );
  if (!context.mounted) return;
  if (picked == null) return;
  ref
      .read(entryFormViewModelProvider(formKey).notifier)
      .applyPickedEndDate(DateTime.utc(picked.year, picked.month, picked.day));
}

Future<void> pushDocumentCrop(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  Uint8List imageBytes,
) async {
  final cropped = await Navigator.of(context, rootNavigator: true)
      .push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => DocumentCropScreen(imageBytes: imageBytes),
        ),
      );
  if (!context.mounted) return;
  if (cropped == null) return;
  ref
      .read(entryFormViewModelProvider(formKey).notifier)
      .applyCroppedDocument(cropped);
}

String? _idFromOutcome(PickerOutcome outcome) => switch (outcome) {
  PickerChose(:final id) => id,
  PickerCleared() => null,
};
