import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ledger/ledger_session.dart';
import 'package:domain/domain.dart';

class CountingLedger extends Ledger {
  CountingLedger({super.state});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

class CountingCache extends AnalysisCache {
  CountingCache({super.runner});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

class SessionHolder extends Notifier<LedgerSession?> {
  @override
  LedgerSession? build() => null;

  void replace(LedgerSession session) => state = session;
}

final sessionHolderProvider = NotifierProvider<SessionHolder, LedgerSession?>(
  SessionHolder.new,
);

class Counted {
  Counted(this.ledger, this.cache);

  final CountingLedger ledger;
  final CountingCache cache;

  LedgerSession get session =>
      LedgerSession(ledger: ledger, analysisCache: cache);
}

Counted countedSession({
  required LedgerState state,
  ComputeRunner runner = syncComputeRunner,
}) {
  final ledger = CountingLedger(state: state);
  final cache = CountingCache(runner: runner);
  cache.start(ledger.bus, sourceRevision: () => ledger.revision);
  addTearDown(cache.dispose);
  return Counted(ledger, cache);
}

ProviderContainer containerFor(LedgerSession Function() session) {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWith(
        (ref) => ref.watch(sessionHolderProvider)?.ledger,
      ),
      ledgerSessionProvider.overrideWith(
        (ref) => ref.watch(sessionHolderProvider),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(sessionHolderProvider.notifier).replace(session());
  return container;
}
