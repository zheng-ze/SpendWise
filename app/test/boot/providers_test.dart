import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_store.dart';

import '../support/in_memory_ledger_store.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

ProviderContainer _containerFor(InMemoryLedgerStore store) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [storeProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

/// The provider starts [AppBoot] itself, fire-and-forget, so the test waits
/// for that in-flight start rather than calling start() again.
Future<Ready> _readyPhase(ProviderContainer container) async {
  final boot = container.read(appBootProvider);
  while (boot.phase is! Ready) {
    await Future<void>.delayed(Duration.zero);
  }
  return boot.phase as Ready;
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

  test('analysisCacheHasJoinedTheBusByTheTimeLedgerIsFirstReachable', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));

    final ready = await _readyPhase(container);
    final cache = container.read(analysisCacheProvider);
    final revisionBeforeMutate = cache.revision;

    ready.ledger.addAccount(_account());

    expect(
      container.read(analysisCacheProvider).revision,
      revisionBeforeMutate + 1,
    );
  });

  test('analysisCacheFollowsTheBusOntoARetriedRuntime', () async {
    final container = _containerFor(InMemoryLedgerStore(hasSeeded: true));
    final boot = container.read(appBootProvider);
    await _readyPhase(container);

    await boot.retry();
    final cache = container.read(analysisCacheProvider);
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
    final cache = container.read(analysisCacheProvider);

    container.dispose();
    // Disposal completes on a later microtask, not synchronously, so this
    // yields once before checking.
    await Future<void>.delayed(Duration.zero);

    expect(() => banner.addListener(() {}), throwsFlutterError);
    expect(() => cache.addListener(() {}), throwsFlutterError);
    expect(() => ready.ledger.addAccount(_account()), throwsFlutterError);
  });
}
