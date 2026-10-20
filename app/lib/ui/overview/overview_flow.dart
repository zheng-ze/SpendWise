import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';

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
  void initState() {
    super.initState();
    // A step emitted before the navigator mounts is dropped, so re-check once mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = navigatorContext;
      if (context == null) return;
      final step = ref.read(overviewViewModelProvider).value?.step;
      if (step != null) handleStep(context, step);
    });
  }

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
    }
    ref.read(overviewViewModelProvider.notifier).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) {
    final shellScope = context
        .dependOnInheritedWidgetOfExactType<ShellPaneScope>();
    if (shellScope == null) return const OverviewScreen();
    return ShellPaneHost(
      pageBuilder: (context, presentation) => OverviewScreen(
        layoutMode: ShellPaneScope.of(context).mode,
        presentation: presentation,
      ),
    );
  }
}
