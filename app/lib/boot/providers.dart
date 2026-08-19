import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/banner_state.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/database_connection.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/persistence_processor.dart';

/// Overridden with an in-memory executor in tests, which keeps the store
/// construction below under test rather than replaced.
final databaseConnectionProvider = Provider<Future<QueryExecutor>>((ref) {
  return openLedgerConnection();
});

/// [LazyDatabase] defers the open, so the store can be built synchronously
/// while [AppBoot] awaits the connection.
final storeProvider = Provider<LedgerStore>((ref) {
  final database = LedgerDatabase(
    LazyDatabase(() => ref.read(databaseConnectionProvider)),
  );
  // Swallowed here since a failed opener's error was already surfaced once.
  ref.onDispose(() => database.close().catchError((_) {}));
  return DriftLedgerStore(database);
});

final bannerStateProvider = ChangeNotifierProvider<BannerState>((ref) {
  return BannerState();
});

final analysisCacheProvider = ChangeNotifierProvider<AnalysisCache>((ref) {
  return AnalysisCache();
});

/// [AppBoot.start] moves from creating the bus to running the first
/// [Ledger.resolvePlans] with no await in between, so nothing outside it can
/// interleave once that stretch begins. The listener below is the seam:
/// `notifyListeners` for the `Ready` phase fires synchronously partway
/// through that same stretch, ahead of resolvePlans, so joining the cache
/// from inside the listener still lands before the first mutate.
final appBootProvider = ChangeNotifierProvider<AppBoot>((ref) {
  final banner = ref.read(bannerStateProvider.notifier);
  final cache = ref.read(analysisCacheProvider.notifier);

  final boot = AppBoot(
    createStore: () async => ref.read(storeProvider),
    seedChanges: seedChanges,
    onSaveState: banner.receiveSaveState,
    onPlanError: banner.receivePlanErrors,
    // LazyDatabase caches a failed open, so both providers need invalidating
    // or a retry just replays the same failure.
    onRetry: () {
      ref.invalidate(storeProvider);
      ref.invalidate(databaseConnectionProvider);
    },
  );

  void joinCacheOnceReady() {
    final phase = boot.phase;
    if (phase is Ready) cache.start(phase.ledger.bus);
  }

  boot.addListener(joinCacheOnceReady);
  ref.onDispose(() => boot.removeListener(joinCacheOnceReady));

  WidgetsBinding.instance.addObserver(boot);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(boot));

  boot.start();
  return boot;
});

final appPhaseProvider = Provider<AppPhase>((ref) {
  return ref.watch(appBootProvider).phase;
});

/// Null outside [Ready]. Screens read this only once boot has settled, and a
/// throw here would just move the null check into every caller instead of
/// removing it, so callers get a phase-shaped answer they can pattern match.
final ledgerProvider = Provider<Ledger?>((ref) {
  final phase = ref.watch(appPhaseProvider);
  return phase is Ready ? phase.ledger : null;
});

final persistenceProcessorProvider = Provider<PersistenceProcessor?>((ref) {
  final phase = ref.watch(appPhaseProvider);
  return phase is Ready ? phase.persistence : null;
});
