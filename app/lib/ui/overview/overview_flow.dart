import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';

sealed class OverviewStep {}

class OverviewFlow extends FlowBase<OverviewStep> {
  const OverviewFlow({super.key});

  @override
  ConsumerState<OverviewFlow> createState() => _OverviewFlowState();
}

class _OverviewFlowState extends FlowBaseState<OverviewStep, OverviewFlow> {
  @override
  void Function() subscribeToStep(void Function(OverviewStep? step) handle) =>
      () {};

  @override
  void handleStep(BuildContext context, OverviewStep step) {
    switch (step) {}
  }

  @override
  Widget buildRoot(BuildContext context) => const OverviewScreen();
}
