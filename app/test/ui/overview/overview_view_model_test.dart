import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

import 'overview_fixture.dart';

Future<ProviderContainer> _keptContainer(Ledger ledger) async {
  final container = overviewContainer(ledger);
  container.listen(overviewViewModelProvider, (_, _) {});
  await settleAnalysis(container, ledger);
  return container;
}

void main() {
  test('a failed Today read is flagged and Retry recomputes', () async {
    final ledger = Ledger(state: defaultState());
    var failing = true;
    final container = overviewContainer(
      ledger,
      runner: (state) =>
          failing ? Future.error(StateError('boom')) : syncComputeRunner(state),
    );
    container.listen(overviewViewModelProvider, (_, _) {});
    await pumpEventQueue();
    expect(
      container.read(overviewViewModelProvider).requireValue.todayFailed,
      isTrue,
    );

    failing = false;
    container.read(overviewViewModelProvider.notifier).retryToday();
    await settleAnalysis(container, ledger);

    final viewState = container.read(overviewViewModelProvider).requireValue;
    expect(viewState.todayFailed, isFalse);
    expect(viewState.today!.spent, Decimal.parse('45.70'));
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
