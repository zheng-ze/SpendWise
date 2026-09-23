import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/persistence/ledger_store.dart';

import '../support/in_memory_ledger_store.dart';

class _GatedFlushStore extends InMemoryLedgerStore {
  _GatedFlushStore({super.hasSeeded});

  Completer<void>? _gate;

  int flushCompletions = 0;

  void armGate() => _gate = Completer<void>();

  void openGate() => _gate?.complete();

  @override
  Future<void> flushNow() async {
    final gate = _gate;
    if (gate != null) await gate.future;
    await super.flushNow();
    flushCompletions += 1;
  }
}

void main() {
  final account = Account(name: 'after boot', type: AccountType.savings);

  AppBoot boot(LedgerStore store) =>
      AppBoot(createStore: () async => store, seedChanges: () => const []);

  test('disposeAndFlushWaitsForAFlushInFlightSoTheWriteSurvives', () async {
    final store = _GatedFlushStore(hasSeeded: true);
    final app = boot(store);
    await app.start();
    (app.phase as Ready).ledger.addAccount(account);

    store.armGate();
    final disposal = app.disposeAndFlush();

    expect(store.flushCompletions, 0);

    store.openGate();
    await disposal;

    expect(store.flushCompletions, 1);
    expect(store.state.moneySources, hasLength(1));
  });

  test('disposeAndFlushIsSafeToCallTwice', () async {
    final store = _GatedFlushStore(hasSeeded: true);
    final app = boot(store);
    await app.start();

    await app.disposeAndFlush();
    await app.disposeAndFlush();

    expect(store.flushCompletions, 1);
  });

  test(
    'disposeAndFlushLeavesTheProviderContainersOwnDisposeCallHarmless',
    () async {
      final store = _GatedFlushStore(hasSeeded: true);
      final app = boot(store);
      await app.start();

      await app.disposeAndFlush();

      expect(app.dispose, returnsNormally);
    },
  );

  test('aFlushErrorDuringSynchronousDisposeIsCaughtNotUnhandled', () async {
    final store = _FailingFlushStore(hasSeeded: true);
    final app = boot(store);
    await app.start();

    final zoneErrors = <Object>[];
    await runZonedGuarded(() async {
      app.dispose();
      await Future<void>.delayed(Duration.zero);
    }, (error, stackTrace) => zoneErrors.add(error));

    expect(zoneErrors, isEmpty);
  });
}

class _FailingFlushStore extends InMemoryLedgerStore {
  _FailingFlushStore({super.hasSeeded});

  @override
  Future<void> flushNow() async {
    throw StateError('flush failed');
  }
}
