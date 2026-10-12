import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

class OverviewFlow extends FlowBase<OverviewStep> {
  const OverviewFlow({
    super.key,
    this.historyRouteBuilder,
    this.onHistorySelected,
  });

  final WidgetBuilder? historyRouteBuilder;
  final VoidCallback? onHistorySelected;

  @override
  ConsumerState<OverviewFlow> createState() => _OverviewFlowState();
}

class _OverviewFlowState extends FlowBaseState<OverviewStep, OverviewFlow> {
  bool _historyRouteOpen = false;

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
        final historyRouteBuilder = widget.historyRouteBuilder;
        if (historyRouteBuilder != null) {
          _pushHistory(context, historyRouteBuilder);
        } else {
          widget.onHistorySelected?.call();
        }
    }
    ref.read(overviewViewModelProvider.notifier).clearStep();
  }

  void _pushHistory(BuildContext context, WidgetBuilder historyRouteBuilder) {
    if (_historyRouteOpen) return;
    _historyRouteOpen = true;
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: historyRouteBuilder))
        .then((_) {
          _historyRouteOpen = false;
        });
  }

  @override
  Widget buildRoot(BuildContext context) => const OverviewScreen();
}
