import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';
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
  Route<void>? _trendsRoute;

  TransactionsViewModel get _screenViewModel =>
      ref.read(transactionsViewModelProvider(widget.initialScope).notifier);

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
        unawaited(openEditEntry(context: context, ref: ref, entryId: entry.id));
      case HistoryTrendsRequested():
        _openTrends(context);
      case PickSourceRequested():
      case PickDestinationRequested():
      case PickCategoryRequested():
      case PickRecurrenceRequested():
      case PickDateRequested():
      case PickEndDateRequested():
      case PickEndsRequested():
      case PickReceiptRequested():
      case DocumentCropRequested():
        break;
    }
    _screenViewModel.clearStep();
  }

  void _openTrends(BuildContext context) {
    if (_trendsRoute != null) return;
    final route = MaterialPageRoute<void>(
      builder: (_) => TrendsFlow(onEnded: _closeTrends),
    );
    _trendsRoute = route;
    Navigator.of(context).push(route);
    route.completed.whenComplete(() {
      if (identical(_trendsRoute, route)) _trendsRoute = null;
    });
  }

  void _closeTrends() {
    final context = navigatorContext;
    if (context == null) return;
    Navigator.of(context).pop();
  }

  @override
  Widget buildRoot(BuildContext context) {
    Widget screen(ShellPagePresentation presentation) => TransactionsScreen(
      scope: widget.initialScope,
      onBackPressed: showsOwnBackButton ? goBack : null,
      backLabel: widget.backLabel,
      presentation: presentation,
    );

    if (widget.initialScope != null) {
      return screen(ShellPagePresentation.fullPage);
    }
    return ShellPaneHost(
      pageBuilder: (_, presentation) => screen(presentation),
    );
  }
}
