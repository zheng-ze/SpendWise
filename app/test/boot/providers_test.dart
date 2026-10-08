import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger_session.dart';
import 'package:spendwise/persistence/ledger_store.dart';

import '../support/in_memory_ledger_store.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

ProviderContainer _containerFor(InMemoryLedgerStore store) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store),
      databaseConnectionProvider.overrideWith(
        (ref) async => NativeDatabase.memory(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<Ready> _readyPhase(ProviderContainer container) async {
  final boot = container.read(appBootProvider);
  while (boot.phase is! Ready) {
    await Future<void>.delayed(Duration.zero);
  }
  return boot.phase as Ready;
}

LedgerSession _readySession(ProviderContainer container) {
  final session = container.read(ledgerSessionProvider);
  expect(session, isNotNull);
  if (session == null) {
    throw StateError('Expected a ready ledger session.');
  }
  return session;
}

void main() {
  test('anOverrideStillWinsOverTheRealStore', () {
    final store = InMemoryLedgerStore(hasSeeded: true);
    final container = _containerFor(store);

    expect(container.read(storeProvider), same(store));
  });

  test('overridingTheStoreLetsBootReachReady', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));

    final ready = await _readyPhase(container);

    expect(ready, isA<Ready>());
  });

  test('analysisCacheIsNullUntilTheLedgerIsReachable', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));

    expect(container.read(ledgerProvider), isNull);
    expect(container.read(ledgerSessionProvider), isNull);

    await _readyPhase(container);

    expect(container.read(ledgerSessionProvider), isNotNull);
  });

  test('analysisCacheHasJoinedTheBusByTheTimeLedgerIsFirstReachable', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));

    final ready = await _readyPhase(container);
    final cache = _readySession(container).analysisCache;
    final revisionBeforeMutate = cache.revision;

    ready.ledger.addAccount(_account());

    expect(
      _readySession(container).analysisCache.revision,
      revisionBeforeMutate + 1,
    );
  });

  test('analysisCacheFollowsTheBusOntoARetriedRuntime', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));
    final boot = container.read(appBootProvider);
    await _readyPhase(container);
    final oldCache = _readySession(container).analysisCache;

    await boot.retry();
    final cache = _readySession(container).analysisCache;
    expect(identical(cache, oldCache), isFalse);
    final revisionBeforeMutate = cache.revision;

    (boot.phase as Ready).ledger.addAccount(_account());

    expect(cache.revision, revisionBeforeMutate + 1);
  });

  test('bannerStateReceivesASaveStateFromTheStore', () async {
    final store = InMemoryLedgerStore(hasSeeded: true);
    final container = _containerFor(store);
    await _readyPhase(container);

    store.errorHandler!(SaveBannerState.retrying);

    expect(
      container.read(bannerStateProvider).message,
      "Couldn't save changes, retrying",
    );
  });

  test('bannerStateReceivesAPlanErrorFromTheLedger', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));
    final ready = await _readyPhase(container);

    ready.ledger.onPlanError!([
      PlanFailure(
        planID: 'plan-1',
        occurrence: DateTime.utc(2026, 1, 1),
        error: UnknownPlan('plan-1'),
      ),
    ]);

    expect(
      container.read(bannerStateProvider).message,
      "A recurring plan couldn't add its entry",
    );
  });

  test('disposingTheContainerDisposesWhatTheProvidersOwn', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));
    final ready = await _readyPhase(container);
    final banner = container.read(bannerStateProvider);
    final cache = _readySession(container).analysisCache;

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(() => banner.addListener(() {}), throwsFlutterError);
    expect(() => cache.addListener(() {}), throwsFlutterError);
    expect(() => ready.ledger.addAccount(_account()), throwsFlutterError);
  });
}
