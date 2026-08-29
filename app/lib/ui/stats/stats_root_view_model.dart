import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StatsTab { income, expense, budgets }

enum StatsRangeMode { month, year }

class StatsRootViewState {
  const StatsRootViewState({required this.tab, required this.range});

  final StatsTab tab;
  final StatsRangeMode range;

  StatsRootViewState copyWith({StatsTab? tab, StatsRangeMode? range}) {
    return StatsRootViewState(tab: tab ?? this.tab, range: range ?? this.range);
  }
}

abstract class StatsRootViewModel {
  void setTab(StatsTab tab);
  void setRange(StatsRangeMode range);
}

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

final statsRootViewModelProvider =
    NotifierProvider<StatsRootNotifier, StatsRootViewState>(
      StatsRootNotifier.new,
    );
