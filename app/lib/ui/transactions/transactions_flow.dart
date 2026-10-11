import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/entry_step_handlers.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

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

class TransactionsFlow extends FlowBase<TransactionsStep> {
  const TransactionsFlow({
    super.key,
    super.onEnded,
    this.initialScope,
    this.onEditSource,
  });

  final TransactionsScope? initialScope;
  final void Function(BuildContext context, String holderId)? onEditSource;

  @override
  ConsumerState<TransactionsFlow> createState() => _TransactionsFlowState();
}

class _TransactionsFlowState
    extends FlowBaseState<TransactionsStep, TransactionsFlow> {
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
        if (entry == null) {
          final scope = widget.initialScope;
          openNewEntry(
            context: context,
            ref: ref,
            sourceId: scope != null && scope.scopeIDs.isNotEmpty
                ? scope.scopeIDs.first
                : null,
          );
        } else {
          _openEntryForm(context, entry.id);
        }
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
        break;
    }
    _screenViewModel.clearStep();
  }

  void _openEntryForm(BuildContext context, String entryId) {
    _formSubscription?.close();
    _openFormKey = entryId;
    _formKeyIsSet = true;
    _formSubscription = ref.listenManual(
      entryFormViewModelProvider(entryId),
      (previous, next) => _handleFormStep(entryId, next.value?.step),
    );
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

    dispatchEntryFormStep(context, ref, formKey, step);
    _formViewModel(formKey).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) => TransactionsScreen(
    scope: widget.initialScope,
    onBackPressed: showsOwnBackButton ? goBack : null,
  );
}
