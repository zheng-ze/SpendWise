import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/stats_root_screen.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

// MARK: - StatsFlow
class StatsFlow extends FlowBase<StatsStep> {
  const StatsFlow({super.key, super.onEnded});

  @override
  ConsumerState<StatsFlow> createState() => _StatsFlowState();
}

// MARK: - StatsFlowState
class _StatsFlowState extends FlowBaseState<StatsStep, StatsFlow> {
  @override
  void Function() subscribeToStep(void Function(StatsStep? step) handle) => ref
      .listenManual(
        statsRootViewModelProvider,
        (previous, StatsRootViewState next) => handle(next.step),
      )
      .close;

  @override
  void handleStep(BuildContext context, StatsStep step) {
    switch (step) {
      case CategoryDetailRequested(
        :final kind,
        :final mainID,
        :final isYearRange,
        :final initialDate,
      ):
        final args = CategoryDetailArgs(
          mainID: mainID,
          kind: kind,
          isYearRange: isYearRange,
          initialDate: initialDate,
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryDetailScreen(args: args),
          ),
        );
    }
    ref.read(statsRootViewModelProvider.notifier).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) =>
      StatsRootScreen(onBackPressed: showsOwnBackButton ? goBack : null);
}
