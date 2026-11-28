import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

import 'overview_fixture.dart';

import '../../ledger/analysis_test_support.dart';

Future<ProviderContainer> _keptContainer(Ledger ledger) async {
  final container = overviewContainer(ledger);
  container.listen(overviewViewModelProvider, (_, _) {});
  await settleAnalysis(container, ledger);
  return container;
}

void main() {
  setUp(silenceDebugPrint);

  test('failed mixed reads are flagged and Retry recomputes', () async {
    final ledger = Ledger(state: defaultState());
    var failing = true;
    final container = overviewContainer(
      ledger,
      runner: (state) =>
          failing ? Future.error(StateError('boom')) : syncComputeRunner(state),
    );
    container.listen(overviewViewModelProvider, (_, _) {});
    await pumpEventQueue();
    final failed = container.read(overviewViewModelProvider).requireValue;
    expect(failed.todayFailed, isTrue);
    expect(failed.thisMonthFailed, isTrue);
    expect(failed.budgetWatchFailed, isTrue);
    expect(failed.budgetWatch, isNull);
    expect(failed.recent, isNotEmpty);
    expect(failed.insightsFailed, isTrue);
    expect(failed.insightsSettledEmpty, isFalse);
    expect(failed.weekSoFarFailed, isTrue);

    failing = false;
    container.read(overviewViewModelProvider.notifier).retryReads();
    await settleAnalysis(container, ledger);

    final viewState = container.read(overviewViewModelProvider).requireValue;
    expect(viewState.todayFailed, isFalse);
    expect(viewState.thisMonthFailed, isFalse);
    expect(viewState.budgetWatchFailed, isFalse);
    expect(viewState.budgetWatch, isEmpty);
    expect(viewState.insightsFailed, isFalse);
    expect(viewState.weekSoFarFailed, isFalse);
    expect(viewState.today!.spent, Decimal.parse('45.70'));
    final figures = viewState.thisMonth!.figures!;
    expect(figures.spent, '-53.70');
    expect(figures.income, '+3,200.00');
    expect(figures.net, '+3,146.30');
  });

  test('a failed breakdown read is flagged and Retry recomputes', () async {
    final ledger = Ledger(state: defaultState());
    var failing = true;
    final container = overviewContainer(
      ledger,
      runner: (state) =>
          failing ? Future.error(StateError('boom')) : syncComputeRunner(state),
    );
    container.listen(overviewViewModelProvider, (_, _) {});
    await pumpEventQueue();
    final failed = container.read(overviewViewModelProvider).requireValue;
    expect(failed.topCategoriesFailed, isTrue);
    expect(failed.topCategories, isNull);

    failing = false;
    container.read(overviewViewModelProvider.notifier).retryReads();
    await settleAnalysis(container, ledger);

    final viewState = container.read(overviewViewModelProvider).requireValue;
    expect(viewState.topCategoriesFailed, isFalse);
    expect(viewState.topCategories, isNotNull);
  });

  test('This month rolls over to the new month with the day', () async {
    var now = DateTime.utc(2026, 10, 31);
    final ledger = Ledger(state: defaultState());
    final container = overviewContainer(ledger, clock: () => now);
    container.listen(overviewViewModelProvider, (_, _) {});
    await settleAnalysis(container, ledger);

    now = DateTime.utc(2026, 11, 1);
    container.invalidate(todayProvider);
    await settleAnalysis(container, ledger);

    final month = container
        .read(overviewViewModelProvider)
        .requireValue
        .thisMonth!;
    expect(month.caption, 'November');
    expect(month.figures!.spent, '-1,200.00');
    expect(month.figures!.income, '0.00');
    expect(month.figures!.net, '-1,200.00');
  });

  group('History step', () {
    test('requestHistory emits an overview history request', () async {
      final container = await _keptContainer(Ledger(state: defaultState()));

      container.read(overviewViewModelProvider.notifier).requestHistory();

      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isA<OverviewHistoryRequested>(),
      );
    });

    test('clearStep clears a pending history request', () async {
      final container = await _keptContainer(Ledger(state: defaultState()));
      container.read(overviewViewModelProvider.notifier).requestHistory();

      container.read(overviewViewModelProvider.notifier).clearStep();

      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });

    test('a pending history request survives a ledger change', () async {
      final ledger = Ledger(state: defaultState());
      final container = await _keptContainer(ledger);
      container.read(overviewViewModelProvider.notifier).requestHistory();

      ledger.addEntry(entry(9, '-1.00', fixtureToday, name: 'Newest'));
      await settleAnalysis(container, ledger);

      final viewState = container.read(overviewViewModelProvider).requireValue;
      expect(viewState.recent!.first.title, 'Newest');
      expect(viewState.step, isA<OverviewHistoryRequested>());
    });

    test('an unmounted view model drops its pending step', () async {
      final container = overviewContainer(Ledger(state: defaultState()));
      final mounted = container.listen(overviewViewModelProvider, (_, _) {});
      container.read(overviewViewModelProvider.notifier).requestHistory();

      mounted.close();
      await container.pump();

      expect(container.read(overviewViewModelProvider).value?.step, isNull);
    });
  });

  group('Budgets step', () {
    test(
      'requestBudgets emits a budgets request that clearStep clears',
      () async {
        final container = await _keptContainer(Ledger(state: defaultState()));
        final notifier = container.read(overviewViewModelProvider.notifier);

        notifier.requestBudgets();
        expect(
          container.read(overviewViewModelProvider).requireValue.step,
          isA<OverviewBudgetsRequested>(),
        );

        notifier.clearStep();
        expect(
          container.read(overviewViewModelProvider).requireValue.step,
          isNull,
        );
      },
    );

    test(
      'requestTrends emits a trends request that clearStep clears',
      () async {
        final container = await _keptContainer(Ledger(state: defaultState()));
        final notifier = container.read(overviewViewModelProvider.notifier);

        notifier.requestTrends();
        expect(
          container.read(overviewViewModelProvider).requireValue.step,
          isA<OverviewTrendsRequested>(),
        );

        notifier.clearStep();
        expect(
          container.read(overviewViewModelProvider).requireValue.step,
          isNull,
        );
      },
    );

    test('requestEditOverview emits an edit-overview request that clearStep clears', () async {
      final container = await _keptContainer(Ledger(state: defaultState()));
      final notifier = container.read(overviewViewModelProvider.notifier);

      notifier.requestEditOverview();
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isA<OverviewEditOverviewRequested>(),
      );

      notifier.clearStep();
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });
  });

  group('Budget step', () {
    test('openBudget emits a budget request that clearStep clears', () async {
      final state = defaultState();
      final budgetID = state.budgets.keys.single;
      final container = await _keptContainer(Ledger(state: state));
      final notifier = container.read(overviewViewModelProvider.notifier);

      notifier.openBudget(budgetID);
      final step = container.read(overviewViewModelProvider).requireValue.step;
      expect(step, isA<OverviewBudgetRequested>());
      expect((step! as OverviewBudgetRequested).budgetID, budgetID);

      notifier.clearStep();
      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });

    test('openBudget emits nothing for an unknown id', () async {
      final container = await _keptContainer(Ledger(state: defaultState()));

      container
          .read(overviewViewModelProvider.notifier)
          .openBudget('00000000-0000-4000-8000-000000000000');

      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });
  });

  group('entry rows', () {
    test('recent rows carry their entry id', () async {
      final container = await _keptContainer(Ledger(state: defaultState()));

      final recent = container
          .read(overviewViewModelProvider)
          .requireValue
          .recent!;

      expect(
        recent.singleWhere((row) => row.title == 'Shop run').entryId,
        entryID(3),
      );
    });

    test('openEntry emits an entry request for an active entry', () async {
      final container = await _keptContainer(Ledger(state: defaultState()));

      container.read(overviewViewModelProvider.notifier).openEntry(entryID(3));

      final step = container.read(overviewViewModelProvider).requireValue.step;
      expect(step, isA<OverviewEntryRequested>());
      expect((step! as OverviewEntryRequested).entryId, entryID(3));
    });

    test('openEntry emits nothing for an unknown id', () async {
      final container = await _keptContainer(Ledger(state: defaultState()));

      container.read(overviewViewModelProvider.notifier).openEntry(entryID(99));

      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });

    test('openEntry emits nothing for an archived entry', () async {
      final ledger = Ledger(state: defaultState());
      final container = await _keptContainer(ledger);
      ledger.archiveEntry(entryID(3));
      await settleAnalysis(container, ledger);

      container.read(overviewViewModelProvider.notifier).openEntry(entryID(3));

      expect(
        container.read(overviewViewModelProvider).requireValue.step,
        isNull,
      );
    });
  });
}
