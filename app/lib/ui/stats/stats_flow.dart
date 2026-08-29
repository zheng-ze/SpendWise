import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/stats_root_screen.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

/// Owns the Stats feature's own nested Navigator, covering the income and
/// expense tabs' category-detail drilldown. The budgets tab is `BudgetsFlow`'s
/// own nested Navigator instead — it renders that tab's whole content and
/// mediates its own steps.
class StatsFlow extends FlowBase<StatsStep> {
  const StatsFlow({super.key});

  @override
  ConsumerState<StatsFlow> createState() => _StatsFlowState();
}

class _StatsFlowState extends FlowBaseState<StatsStep, StatsFlow> {
  @override
  void Function() subscribeToStep(void Function(StatsStep? step) handle) => ref
      .listenManual(
        statsRootViewModelProvider,
        (previous, AsyncValue<StatsRootViewState> next) =>
            handle(next.value?.step),
      )
      .close;

  @override
  void handleStep(BuildContext context, StatsStep step) {
    switch (step) {
      case CategoryDetailRequested(
        :final mainID,
        :final kind,
        :final isYearRange,
        :final initialDate,
      ):
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryDetailScreen(
              args: CategoryDetailArgs(
                mainID: mainID,
                kind: kind,
                isYearRange: isYearRange,
                initialDate: initialDate,
              ),
            ),
          ),
        );
    }
    ref.read(statsRootViewModelProvider.notifier).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) => const StatsRootScreen();
}
