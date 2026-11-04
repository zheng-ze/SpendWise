import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/trends_flow.dart';
import 'package:spendwise/ui/transactions/daily_list/daily_transactions_screen.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_host.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/history_entry_selection.dart';
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
        _editEntry(context, entry.id);
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

  void _editEntry(BuildContext context, String entryId) {
    final paneHosted =
        widget.initialScope == null &&
        ref.read(shellLayoutModeProvider) != ShellLayoutMode.phone;
    if (!paneHosted) {
      unawaited(openEditEntry(context: context, ref: ref, entryId: entryId));
      return;
    }
    if (ref.read(historyEntrySelectionProvider) == entryId) return;
    ref.invalidate(entryFormViewModelProvider(entryId));
    ref.read(historyEntrySelectionProvider.notifier).select(entryId);
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
    return _HistoryPaneHost(pageBuilder: screen);
  }
}

// MARK: - HistoryPaneHost
class _HistoryPaneHost extends ConsumerWidget {
  const _HistoryPaneHost({required this.pageBuilder});

  final Widget Function(ShellPagePresentation presentation) pageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(shellLayoutModeProvider) == ShellLayoutMode.phone;
    final entryId = ref.watch(historyEntrySelectionProvider);
    final showsPane = !phone && entryId != null;
    final draftDate = showsPane
        ? ref.watch(
            entryFormViewModelProvider(entryId).select((s) => s.value?.date),
          )
        : null;
    final clear = ref.read(historyEntrySelectionProvider.notifier).clear;
    ShellDetail? detail;
    if (showsPane) {
      detail = ShellDetail(
        id: entryId,
        title: editEntryTitle,
        subtitle: draftDate == null ? null : formatEntryDate(draftDate),
        onClose: clear,
        bodyBuilder: (_) => EditEntryHost(
          entryId: entryId,
          frame: EntryFormFrame.pane,
          onDismiss: clear,
        ),
      );
    }
    return ShellPaneHost(
      pageBuilder: (_, presentation) => pageBuilder(presentation),
      detail: detail,
    );
  }
}
