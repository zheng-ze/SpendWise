import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/stats_root_view_model.dart';

void main() {
  test('build defaults to the expense tab and monthly range', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(statsRootViewModelProvider);

    expect(state.tab, StatsTab.expense);
    expect(state.range, StatsRangeMode.month);
  });

  test('setTab and setRange update the view state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final viewModel = container.read(statsRootViewModelProvider.notifier);

    viewModel.setTab(StatsTab.budgets);
    expect(container.read(statsRootViewModelProvider).tab, StatsTab.budgets);

    viewModel.setRange(StatsRangeMode.year);
    expect(
      container.read(statsRootViewModelProvider).range,
      StatsRangeMode.year,
    );
  });
}
