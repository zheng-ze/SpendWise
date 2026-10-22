// import 'package:domain/domain.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_test/flutter_test.dart';
//
// import 'package:spendwise/ui/stats/stats_root_view_model.dart';
//
// void main() {
// Temporary: this test depends on the removed Stats root/Flow and MUST be resolved when the new Trends screen is ready.
//   test('build defaults to the expense tab and monthly range', () {
//     final container = ProviderContainer();
//     addTearDown(container.dispose);
//
//     final state = container.read(statsRootViewModelProvider);
//
//     expect(state.tab, StatsTab.expense);
//     expect(state.range, StatsRangeMode.month);
//   });
//
// Temporary: this test depends on the removed Stats root/Flow and MUST be resolved when the new Trends screen is ready.
//   test('setTab and setRange update the view state', () {
//     final container = ProviderContainer();
//     addTearDown(container.dispose);
//     final viewModel = container.read(statsRootViewModelProvider.notifier);
//
//     viewModel.setTab(StatsTab.income);
//     expect(container.read(statsRootViewModelProvider).tab, StatsTab.income);
//     viewModel.setTab(StatsTab.expense);
//     expect(container.read(statsRootViewModelProvider).tab, StatsTab.expense);
//
//     viewModel.setRange(StatsRangeMode.year);
//     expect(
//       container.read(statsRootViewModelProvider).range,
//       StatsRangeMode.year,
//     );
//   });
//
// Temporary: this test depends on the removed Stats root/Flow and MUST be resolved when the new Trends screen is ready.
//   test(
//     'requestCategoryDetail emits a step carrying its kind until cleared',
//     () {
//       final container = ProviderContainer();
//       addTearDown(container.dispose);
//       final viewModel = container.read(statsRootViewModelProvider.notifier);
//       final date = DateTime.utc(2026, 3);
//
//       viewModel.requestCategoryDetail(
//         kind: CategoryKind.income,
//         mainID: 'c0000000-0000-0000-0000-000000000002',
//         isYearRange: true,
//         initialDate: date,
//       );
//
//       final step = container.read(statsRootViewModelProvider).step;
//       expect(step, isA<CategoryDetailRequested>());
//       final requested = step as CategoryDetailRequested;
//       expect(requested.kind, CategoryKind.income);
//       expect(requested.isYearRange, isTrue);
//       expect(requested.initialDate, date);
//
//       viewModel.clearStep();
//       expect(container.read(statsRootViewModelProvider).step, isNull);
//     },
//   );
// }

void main() {}
