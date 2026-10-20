import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/step_emitting.dart';

// MARK: - StatsTab
enum StatsTab { income, expense }

// MARK: - StatsRangeMode
enum StatsRangeMode { month, year }

// MARK: - Steps
sealed class StatsStep {}

class CategoryDetailRequested extends StatsStep {
  CategoryDetailRequested({
    required this.kind,
    required this.mainID,
    required this.isYearRange,
    required this.initialDate,
  });

  final CategoryKind kind;
  final String mainID;
  final bool isYearRange;
  final DateTime initialDate;
}

// MARK: - StatsRootViewState
class StatsRootViewState implements HasStep<StatsRootViewState, StatsStep> {
  const StatsRootViewState({required this.tab, required this.range, this.step});

  final StatsTab tab;
  final StatsRangeMode range;
  @override
  final StatsStep? step;

  StatsRootViewState copyWith({
    StatsTab? tab,
    StatsRangeMode? range,
    StatsStep? Function()? step,
  }) {
    return StatsRootViewState(
      tab: tab ?? this.tab,
      range: range ?? this.range,
      step: step == null ? this.step : step(),
    );
  }

  @override
  StatsRootViewState withStep(StatsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - StatsRootViewModel
abstract class StatsRootViewModel {
  void setTab(StatsTab tab);
  void setRange(StatsRangeMode range);
  void requestCategoryDetail({
    required CategoryKind kind,
    required String mainID,
    required bool isYearRange,
    required DateTime initialDate,
  });
  void clearStep();
}

// MARK: - StatsRootNotifier
class StatsRootNotifier extends Notifier<StatsRootViewState>
    with StepEmitting<StatsRootViewState, StatsStep>
    implements StatsRootViewModel {
  @override
  StatsRootViewState build() => const StatsRootViewState(
    tab: StatsTab.expense,
    range: StatsRangeMode.month,
  );

  @override
  void setTab(StatsTab tab) {
    state = state.copyWith(tab: tab);
  }

  @override
  void setRange(StatsRangeMode range) {
    state = state.copyWith(range: range);
  }

  @override
  void updateState(
    StatsRootViewState Function(StatsRootViewState current) apply,
  ) {
    state = apply(state);
  }

  @override
  void requestCategoryDetail({
    required CategoryKind kind,
    required String mainID,
    required bool isYearRange,
    required DateTime initialDate,
  }) => emitStep(
    CategoryDetailRequested(
      kind: kind,
      mainID: mainID,
      isYearRange: isYearRange,
      initialDate: initialDate,
    ),
  );
}

// MARK: - Constants
final statsRootViewModelProvider =
    NotifierProvider<StatsRootNotifier, StatsRootViewState>(
      StatsRootNotifier.new,
    );
