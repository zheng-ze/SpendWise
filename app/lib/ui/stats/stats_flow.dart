import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/stats/stats_root_screen.dart';

// MARK: - Steps
sealed class StatsStep {}

// MARK: - StatsFlow
class StatsFlow extends FlowBase<StatsStep> {
  const StatsFlow({super.key});

  @override
  ConsumerState<StatsFlow> createState() => _StatsFlowState();
}

// MARK: - StatsFlowState
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
