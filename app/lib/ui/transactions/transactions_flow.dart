import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/category_picker.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/common/recurrence_picker.dart';
import 'package:spendwise/ui/common/source_picker.dart';
import 'package:spendwise/ui/common/two_column_picker_sheet.dart';
import 'package:spendwise/ui/transactions/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/document_crop_screen.dart';
import 'package:spendwise/ui/transactions/entry_form.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart'
    show EntryFormKind;
import 'package:spendwise/ui/transactions/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

/// Identifies which holders a scoped Transactions screen filters to, and
/// what title it shows. Null [TransactionsFlow.initialScope] means the
/// unscoped shell tab.
class TransactionsScope {
  const TransactionsScope({required this.title, required this.scopeIDs});

  final String title;
  final Set<String> scopeIDs;

  @override
  bool operator ==(Object other) =>
      other is TransactionsScope &&
      other.title == title &&
      other.scopeIDs.length == scopeIDs.length &&
      other.scopeIDs.containsAll(scopeIDs);

  @override
  int get hashCode => Object.hash(title, Object.hashAllUnordered(scopeIDs));
}

/// Owns the Transactions feature's own nested Navigator. Pushed directly by
/// the app shell when [initialScope] is null, or pushed by `AccountsFlow`
/// with a scope when reached from an account/pocket row.
class TransactionsFlow extends FlowBase<TransactionsStep> {
  const TransactionsFlow({super.key, this.initialScope, this.onEditSource});

  final TransactionsScope? initialScope;
  final void Function(BuildContext context, String holderId)? onEditSource;

  @override
  ConsumerState<TransactionsFlow> createState() => _TransactionsFlowState();
}

class _TransactionsFlowState
    extends FlowBaseState<TransactionsStep, TransactionsFlow> {
  // Re-created whenever an entry form opens, since the form's ViewModel is a
  // family instance keyed by which entry (or null, for a new entry) it
  // edits, so there is no one fixed provider to subscribe to up front.
  ProviderSubscription<AsyncValue<EntryFormViewState>>? _formSubscription;
  String? _openFormKey;
  bool _formKeyIsSet = false;

  @override
  void dispose() {
    _formSubscription?.close();
    super.dispose();
  }

  TransactionsViewModel get _screenViewModel =>
      ref.read(transactionsViewModelProvider(widget.initialScope).notifier);

  EntryFormViewModel _formViewModel(String? key) =>
      ref.read(entryFormViewModelProvider(key).notifier);

  @override
  void Function() subscribeToStep(
    void Function(TransactionsStep? step) handle,
  ) => ref
      .listenManual(
        transactionsViewModelProvider(widget.initialScope),
        (previous, AsyncValue<TransactionsViewState> next) =>
            handle(next.value?.step),
      )
      .close;

  @override
  void handleStep(BuildContext context, TransactionsStep step) {
    switch (step) {
      case EntryFormRequested(:final entry):
        _openEntryForm(context, entry?.id);
      case SourceEditRequested():
        final scope = widget.initialScope;
        if (scope != null && scope.scopeIDs.isNotEmpty) {
          widget.onEditSource?.call(context, scope.scopeIDs.first);
        }
      case PickSourceRequested():
      case PickDestinationRequested():
      case PickCategoryRequested():
      case PickRecurrenceRequested():
      case PickDateRequested():
      case PickEndDateRequested():
      case DocumentCropRequested():
        // These variants are only ever emitted by an EntryFormViewModel's
        // own state, handled by _handleFormStep below.
        break;
    }
    _screenViewModel.clearStep();
  }

  void _openEntryForm(BuildContext context, String? entryId) {
    _formSubscription?.close();
    _openFormKey = entryId;
    _formKeyIsSet = true;
    _formSubscription = ref.listenManual(
      entryFormViewModelProvider(entryId),
      (previous, next) => _handleFormStep(entryId, next.value?.step),
    );
    if (entryId == null) {
      final scope = widget.initialScope;
      if (scope != null && scope.scopeIDs.isNotEmpty) {
        _formViewModel(entryId).prefillSource(scope.scopeIDs.first);
      }
    }
    showEntryFormSheet(context: context, entryId: entryId).whenComplete(() {
      if (_openFormKey == entryId) {
        _formSubscription?.close();
        _formSubscription = null;
        _formKeyIsSet = false;
      }
    });
  }

  void _handleFormStep(String? formKey, TransactionsStep? step) {
    if (step == null) return;
    if (!_formKeyIsSet || _openFormKey != formKey) return;
    final context = navigatorContext;
    if (context == null) return;

    switch (step) {
      case PickSourceRequested():
        _pickSource(context, formKey);
      case PickDestinationRequested():
        _pickDestination(context, formKey);
      case PickCategoryRequested():
        _pickCategory(context, formKey);
      case PickRecurrenceRequested():
        _pickRecurrence(context, formKey);
      case PickDateRequested():
        _pickDate(context, formKey);
      case PickEndDateRequested():
        _pickEndDate(context, formKey);
      case DocumentCropRequested(:final imageBytes):
        _pushDocumentCrop(context, formKey, imageBytes);
      case EntryFormRequested():
      case SourceEditRequested():
        // Only TransactionsViewModel emits these; unreachable here.
        break;
    }
    _formViewModel(formKey).clearStep();
  }

  Future<void> _pickSource(BuildContext context, String? formKey) async {
    final ledger = ref.read(ledgerProvider);
    if (ledger == null) return;
    final formState = ref.read(entryFormViewModelProvider(formKey)).value;
    final outcome = await showSourcePickerSheet(
      context: context,
      title: formState?.kind == EntryFormKind.transfer ? 'From' : 'Account',
      state: ledger.state,
      selectedId: formState?.sourceId,
    );
    if (!context.mounted) return;
    if (outcome == null) return;
    _formViewModel(formKey).applyPickedSource(_idFromOutcome(outcome));
  }

  Future<void> _pickDestination(BuildContext context, String? formKey) async {
    final ledger = ref.read(ledgerProvider);
    if (ledger == null) return;
    final formState = ref.read(entryFormViewModelProvider(formKey)).value;
    final outcome = await showSourcePickerSheet(
      context: context,
      title: 'To',
      state: ledger.state,
      selectedId: formState?.destinationId,
    );
    if (!context.mounted) return;
    if (outcome == null) return;
    _formViewModel(formKey).applyPickedDestination(_idFromOutcome(outcome));
  }

  Future<void> _pickCategory(BuildContext context, String? formKey) async {
    final ledger = ref.read(ledgerProvider);
    if (ledger == null) return;
    final formState = ref.read(entryFormViewModelProvider(formKey)).value;
    final categoryKind = formState?.kind == EntryFormKind.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final outcome = await showCategoryPickerSheet(
      context: context,
      state: ledger.state,
      kind: categoryKind,
      selectedId: formState?.categoryId,
    );
    if (!context.mounted) return;
    if (outcome == null) return;
    _formViewModel(formKey).applyPickedCategory(_idFromOutcome(outcome));
  }

  Future<void> _pickRecurrence(BuildContext context, String? formKey) async {
    final formState = ref.read(entryFormViewModelProvider(formKey)).value;
    final chosen = await showRecurrencePickerSheet(
      context: context,
      selected: formState?.recurrence,
    );
    if (!context.mounted) return;
    _formViewModel(formKey).applyPickedRecurrence(chosen);
  }

  Future<void> _pickDate(BuildContext context, String? formKey) async {
    final formState = ref.read(entryFormViewModelProvider(formKey)).value;
    final picked = await showDatePicker(
      context: context,
      initialDate: formState?.date ?? DateTime.now(),
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (!context.mounted) return;
    if (picked == null) return;
    _formViewModel(
      formKey,
    ).applyPickedDate(DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _pickEndDate(BuildContext context, String? formKey) async {
    final formState = ref.read(entryFormViewModelProvider(formKey)).value;
    final initial = formState?.endDate ?? formState?.date ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: formState?.date ?? DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (!context.mounted) return;
    if (picked == null) return;
    _formViewModel(
      formKey,
    ).applyPickedEndDate(DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _pushDocumentCrop(
    BuildContext context,
    String? formKey,
    Uint8List imageBytes,
  ) async {
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => DocumentCropScreen(imageBytes: imageBytes),
      ),
    );
    if (!context.mounted) return;
    if (cropped == null) return;
    _formViewModel(formKey).applyCroppedDocument(cropped);
  }

  @override
  Widget buildRoot(BuildContext context) =>
      TransactionsScreen(scope: widget.initialScope);
}

String? _idFromOutcome(PickerOutcome outcome) => switch (outcome) {
  PickerChose(:final id) => id,
  PickerCleared() => null,
};
