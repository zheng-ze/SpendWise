import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_step_handlers.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

// MARK: - TransactionsScope
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

// MARK: - TransactionsFlow
class TransactionsFlow extends FlowBase<TransactionsStep> {
  const TransactionsFlow({
    super.key,
    super.onEnded,
    this.initialScope,
    this.backLabel,
  });

  final TransactionsScope? initialScope;
  final String? backLabel;

  @override
  ConsumerState<TransactionsFlow> createState() => _TransactionsFlowState();
}

// MARK: - TransactionsFlowState
class _TransactionsFlowState
    extends FlowBaseState<TransactionsStep, TransactionsFlow> {
  ProviderSubscription<AsyncValue<EntryFormViewState>>? _formSubscription;
  String? _openFormKey;
  bool _formKeyIsSet = false;
  bool _active = false;

  @override
  void dispose() {
    _formSubscription?.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = DestinationActivity.of(context);
    final becameActive = active && !_active;
    _active = active;
    if (becameActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navContext = navigatorContext;
        if (navContext == null) return;
        if (!DestinationActivity.of(navContext)) return;
        final pending = ref
            .read(transactionsViewModelProvider(widget.initialScope))
            .value
            ?.step;
        if (pending == null) return;
        handleStep(navContext, pending);
      });
    }
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
    if (!DestinationActivity.of(context)) return;
    final current = ref
        .read(transactionsViewModelProvider(widget.initialScope))
        .value
        ?.step;
    if (!identical(current, step)) return;
    switch (step) {
      case EntryFormRequested(:final entry):
        _openEntryForm(context, entry.id);
      case PickSourceRequested():
      case PickDestinationRequested():
      case PickCategoryRequested():
      case PickRecurrenceRequested():
      case PickDateRequested():
      case PickEndDateRequested():
      case PickEndsRequested():
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
    backLabel: widget.backLabel,
  );
}
