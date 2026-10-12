import 'package:flutter_riverpod/flutter_riverpod.dart';

// MARK: - StatsTab
enum StatsTab { income, expense, budgets }

// MARK: - StatsRangeMode
enum StatsRangeMode { month, year }

// MARK: - StatsRootViewState
class StatsRootViewState {
  const StatsRootViewState({required this.tab, required this.range});

  final StatsTab tab;
  final StatsRangeMode range;

  StatsRootViewState copyWith({StatsTab? tab, StatsRangeMode? range}) {
    return StatsRootViewState(tab: tab ?? this.tab, range: range ?? this.range);
  }
}

// MARK: - StatsRootViewModel
abstract class StatsRootViewModel {
  void setTab(StatsTab tab);
  void setRange(StatsRangeMode range);
}

// MARK: - StatsRootNotifier
class StatsRootNotifier extends Notifier<StatsRootViewState>
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
}

// MARK: - Constants
final statsRootViewModelProvider =
    NotifierProvider<StatsRootNotifier, StatsRootViewState>(
      StatsRootNotifier.new,
    );
