import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';

// MARK: - OverviewFlow
class OverviewFlow extends FlowBase<OverviewStep> {
  const OverviewFlow({super.key, required this.onHistorySelected});

  final VoidCallback onHistorySelected;

  @override
  ConsumerState<OverviewFlow> createState() => _OverviewFlowState();
}

// MARK: - OverviewFlowState
class _OverviewFlowState extends FlowBaseState<OverviewStep, OverviewFlow> {
  @override
  void Function() subscribeToStep(void Function(OverviewStep? step) handle) =>
      ref
          .listenManual(
            overviewViewModelProvider,
            (previous, AsyncValue<OverviewViewState> next) =>
                handle(next.value?.step),
          )
          .close;

  @override
  void handleStep(BuildContext context, OverviewStep step) {
    switch (step) {
      case OverviewHistoryRequested():
        widget.onHistorySelected();
      case OverviewEntryRequested(:final entryId):
        unawaited(openEditEntry(context: context, ref: ref, entryId: entryId));
    }
    ref.read(overviewViewModelProvider.notifier).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) {
    return ShellPaneHost(
      pageBuilder: (context, presentation) => OverviewScreen(
        layoutMode: ShellPaneScope.of(context).mode,
        presentation: presentation,
      ),
    );
  }
}
