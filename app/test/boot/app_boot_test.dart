import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/persistence/ledger_store.dart';

import '../support/recording_ledger_store.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

List<LedgerChange> _seed(Account account) => [UpsertAccount(account)];

AppBoot _boot(
  RecordingLedgerStore store, {
  List<LedgerChange> seed = const [],
}) => AppBoot(createStore: () async => store, seedChanges: () => seed);

void main() {
  test('storeIsWiredForErrorsBeforeSeedingAndSeededBeforeLoad', () async {
    final store = RecordingLedgerStore();

    await _boot(store, seed: _seed(_account())).start();

    expect(
      store.calls.where((call) => call != StoreCall.start).toList(),
      containsAllInOrder([
        StoreCall.setErrorHandler,
        StoreCall.seedIfFirstLaunch,
        StoreCall.load,
      ]),
    );
  });

  test('readyCarriesTheLoadedState', () async {
    final account = _account(name: 'loaded');
    final store = RecordingLedgerStore(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
      hasSeeded: true,
    );

    final boot = _boot(store);
    await boot.start();

    final phase = boot.phase;
    expect(phase, isA<Ready>());
    expect((phase as Ready).ledger.state.moneySources, contains(account.id));
  });

  test('processorIsStartedBeforeReady', () async {
    final store = RecordingLedgerStore();

    final boot = _boot(store);
    await boot.start();

    expect(store.isStarted, isTrue);
    expect((boot.phase as Ready).persistence.store, same(store));
  });

  test('phaseIsLoadingUntilStartCompletes', () async {
    final store = RecordingLedgerStore();
    final boot = _boot(store);

    expect(boot.phase, isA<Loading>());

    final pending = boot.start();
    expect(boot.phase, isA<Loading>());

    await pending;
    expect(boot.phase, isA<Ready>());
  });

  group('a throw at any step lands in failed', () {
    for (final step in StoreCall.values) {
      test('failsWhen${step.name}Throws', () async {
        final store = RecordingLedgerStore()..failOn = step;

        final boot = _boot(store, seed: _seed(_account()));
        await boot.start();

        final phase = boot.phase;
        expect(phase, isA<Failed>());
        expect((phase as Failed).error, same(store.failure));
      });
    }
  });

  test('failsWhenStoreCreationThrows', () async {
    final failure = StateError('no store');
    final boot = AppBoot(
      createStore: () async => throw failure,
      seedChanges: () => const [],
    );

    await boot.start();

    expect((boot.phase as Failed).error, same(failure));
  });

  test('failsWhenSeedBuilderThrows', () async {
    final failure = StateError('bad seed');
    final store = RecordingLedgerStore();
    final boot = AppBoot(
      createStore: () async => store,
      seedChanges: () => throw failure,
    );

    await boot.start();

    expect((boot.phase as Failed).error, same(failure));
    expect(store.calls, isNot(contains(StoreCall.load)));
  });

  test('utcNowForKeepsTheLocalCalendarDayInsteadOfShiftingItViaToUtc', () {
    final justAfterLocalMidnight = DateTime(2026, 1, 15, 0, 30);

    expect(
      AppBoot.utcNowFor(justAfterLocalMidnight),
      DateTime.utc(2026, 1, 15),
    );
  });

  test('mutationThroughTheBootedLedgerReachesTheStore', () async {
    final store = RecordingLedgerStore(hasSeeded: true);
    final boot = _boot(store);
    await boot.start();

    final ready = boot.phase as Ready;
    final account = _account(name: 'after boot');
    ready.ledger.addAccount(account);
    await ready.persistence.flush();

    expect(store.state.moneySources, contains(account.id));
  });

  test('planErrorsFromTheBootedLedgerReachTheHandler', () async {
    final store = RecordingLedgerStore(hasSeeded: true);
    final failures = <List<PlanFailure>>[];
    final boot = AppBoot(
      createStore: () async => store,
      seedChanges: () => const [],
      onPlanError: failures.add,
    );
    await boot.start();

    final ready = boot.phase as Ready;
    ready.ledger.onPlanError!(const []);

    expect(failures, hasLength(1));
  });

  test('saveFailuresFromTheStoreReachTheHandler', () async {
    final store = RecordingLedgerStore(hasSeeded: true);
    final states = <SaveBannerState>[];
    final boot = AppBoot(
      createStore: () async => store,
      seedChanges: () => const [],
      onSaveState: states.add,
    );
    await boot.start();

    store.errorHandler!(SaveBannerState.retrying);

    expect(states, [SaveBannerState.retrying]);
  });

  test('seedSaveFailureSurfacesThroughTheErrorHandler', () async {
    final states = <SaveBannerState>[];
    final store = _SeedFailingStore();
    final boot = AppBoot(
      createStore: () async => store,
      seedChanges: () => _seed(_account()),
      onSaveState: states.add,
    );

    await boot.start();

    expect(states, [SaveBannerState.failedWillRetry]);
  });
}

class _SeedFailingStore extends RecordingLedgerStore {
  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) async {
    errorHandler?.call(SaveBannerState.failedWillRetry);
    return super.seedIfFirstLaunch(changes);
  }
}
