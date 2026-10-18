import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/pickers/category_picker.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/ends_choice_sheet.dart';
import 'package:spendwise/ui/common/pickers/receipt_choice_sheet.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/common/pickers/source_picker.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/document_crop/document_crop_screen.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart'
    show EntryFormKind;
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart'
    show ReceiptScanSource;
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
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
  void Function(AppSheetRoute<ReceiptChoice>)? onReceiptRouteCreated,
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
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
      );
    case PickDestinationRequested():
      _pickDestination(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
      );
    case PickCategoryRequested():
      _pickCategory(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
      );
    case PickRecurrenceRequested():
      _pickRecurrence(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
      );
    case PickDateRequested():
      _pickDate(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
      );
    case PickEndDateRequested():
      _pickEndDate(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
      );
    case PickEndsRequested():
      _pickEnds(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
      );
    case PickReceiptRequested():
      _pickReceipt(
        context,
        ref,
        formKey,
        form,
        isCurrent: isCurrent,
        sheetPresentation: sheetPresentation,
        onRouteCreated: onReceiptRouteCreated,
      );
    case DocumentCropRequested(:final imageBytes):
      _pushDocumentCrop(
        context,
        form,
        imageBytes,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
      );
    case EntryFormRequested():
      break;
  }
}

bool _isCurrent(bool Function()? isCurrent) => isCurrent?.call() ?? true;

// MARK: - Source Pickers
Future<void> _pickSource(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final outcome = await showSourcePickerSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    sheetPresentation: sheetPresentation,
    title: formState?.kind == EntryFormKind.transfer ? 'From' : 'Account',
    state: ledger.state,
    selectedId: formState?.sourceId,
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  if (outcome == null) return;
  form.applyPickedSource(_idFromOutcome(outcome));
}

Future<void> _pickDestination(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) async {
  final ledger = ref.read(ledgerProvider);
  if (ledger == null) return;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final outcome = await showSourcePickerSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    sheetPresentation: sheetPresentation,
    title: 'To',
    state: ledger.state,
    selectedId: formState?.destinationId,
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
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
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
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
    sheetPresentation: sheetPresentation,
    state: ledger.state,
    kind: categoryKind,
    selectedId: formState?.categoryId,
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  if (outcome == null) return;
  form.applyPickedCategory(_idFromOutcome(outcome));
}

Future<void> _pickRecurrence(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final chosen = await showRecurrencePickerSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    sheetPresentation: sheetPresentation,
    selected: formState?.recurrence,
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  form.applyPickedRecurrence(chosen);
}

String _idFromOutcome(PickerOutcome outcome) => switch (outcome) {
  PickerChose(:final id) => id,
};

// MARK: - Date Pickers
Future<DateTime?> _chooseDate({
  required BuildContext context,
  required bool useRootNavigator,
  required AppSheetPresentation Function(BuildContext)? sheetPresentation,
  required String title,
  required DateTime initialDate,
  required DateTime firstDate,
}) {
  final lastDate = DateTime.utc(_datePickerLastYear);
  final presentation = sheetPresentation;
  if (presentation == null) {
    return showDatePicker(
      context: context,
      useRootNavigator: useRootNavigator,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
  return showDatePickerSheet(
    context: context,
    presentation: presentation,
    title: title,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}

Future<void> _pickDate(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final picked = await _chooseDate(
    context: context,
    useRootNavigator: useRootNavigator,
    sheetPresentation: sheetPresentation,
    title: 'Date',
    initialDate: formState?.date ?? DateTime.now(),
    firstDate: DateTime.utc(_datePickerFirstYear),
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  if (picked == null) return;
  form.applyPickedDate(startOfDayUtc(picked));
}

Future<void> _pickEndDate(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) async {
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final picked = await _chooseDate(
    context: context,
    useRootNavigator: useRootNavigator,
    sheetPresentation: sheetPresentation,
    title: 'End date',
    initialDate: formState?.endDate ?? formState?.date ?? DateTime.now(),
    firstDate: formState?.date ?? DateTime.utc(_datePickerFirstYear),
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  if (picked == null) return;
  form.applyPickedEndDate(startOfDayUtc(picked));
}

Future<void> _pickEnds(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool useRootNavigator = false,
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) async {
  final presentation = sheetPresentation;
  final provider = entryFormViewModelProvider(formKey);
  final formState = ref.read(provider).value;
  final addable =
      formState?.mode == EntryFormMode.newEntry &&
      formState?.recurrence != null;
  if (presentation == null || !addable || !_isCurrent(isCurrent)) return;
  if (!context.mounted) return;
  final choice = await showEndsChoiceSheet(
    context: context,
    presentation: presentation,
    hasEndDate: formState!.hasEndDate,
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  if (ref.read(provider).value?.recurrence == null) return;
  switch (choice) {
    case null:
      return;
    case EndsChoice.never:
      form.setEndDateEnabled(false);
    case EndsChoice.chooseDate:
      await _pickEndDate(
        context,
        ref,
        formKey,
        form,
        useRootNavigator: useRootNavigator,
        isCurrent: isCurrent,
        sheetPresentation: presentation,
      );
  }
}

Future<void> _pickReceipt(
  BuildContext context,
  WidgetRef ref,
  String? formKey,
  EntryFormNotifier form, {
  bool Function()? isCurrent,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
  void Function(AppSheetRoute<ReceiptChoice>)? onRouteCreated,
}) async {
  final presentation = sheetPresentation;
  final formState = ref.read(entryFormViewModelProvider(formKey)).value;
  final addable =
      formState?.mode == EntryFormMode.newEntry && formState?.scanning == false;
  if (presentation == null || !addable || !_isCurrent(isCurrent)) return;
  if (!context.mounted) return;
  final choice = await showReceiptChoiceSheet(
    context: context,
    presentation: presentation,
    onRouteCreated: onRouteCreated,
  );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  switch (choice) {
    case null:
      return;
    case ReceiptChoice.scan:
      form.requestScan(ReceiptScanSource.camera);
    case ReceiptChoice.photo:
      form.requestScan(ReceiptScanSource.gallery);
  }
}

// MARK: - Document Cropping
Future<void> _pushDocumentCrop(
  BuildContext context,
  EntryFormNotifier form,
  Uint8List imageBytes, {
  bool useRootNavigator = false,
  bool Function()? isCurrent,
}) async {
  final cropped = await Navigator.of(context, rootNavigator: useRootNavigator)
      .push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => DocumentCropScreen(imageBytes: imageBytes),
        ),
      );
  if (!context.mounted || !_isCurrent(isCurrent)) return;
  if (cropped == null) return;
  form.applyCroppedDocument(cropped);
}
