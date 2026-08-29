import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/stats/stats_root_screen.dart';

// No variants: AnalysisFlow and BudgetsFlow now mediate their own tab's
// navigation. StatsFlow stays a Flow anyway so every tab is one, per ADR-0059.
sealed class StatsStep {}

class StatsFlow extends FlowBase<StatsStep> {
  const StatsFlow({super.key});

  @override
  ConsumerState<StatsFlow> createState() => _StatsFlowState();
}

class _StatsFlowState extends FlowBaseState<StatsStep, StatsFlow> {
  @override
  void Function() subscribeToStep(void Function(StatsStep? step) handle) =>
      () {};

  @override
  void handleStep(BuildContext context, StatsStep step) {
    switch (step) {}
  }

  @override
  Widget buildRoot(BuildContext context) => const StatsRootScreen();
}
