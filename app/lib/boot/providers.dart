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
import 'package:spendwise/sync/sync_metadata_store.dart';

/// Overridden with an in-memory executor in tests.
// The override keeps the store below under test rather than replacing it.
final databaseConnectionProvider = Provider<Future<QueryExecutor>>((ref) {
  return openLedgerConnection();
});

/// Sole owner of the shared database. Both the ledger store and the sync
/// metadata store below build from this one instance, so boot opens exactly
/// one database.
final ledgerDatabaseProvider = Provider<LedgerDatabase>((ref) {
  final database = LedgerDatabase(
    LazyDatabase(() => ref.read(databaseConnectionProvider)),
  );
  // Swallowed here since a failed opener's error was already surfaced once.
  ref.onDispose(() => database.close().catchError((_) {}));
  return database;
});

/// Builds the store synchronously around the shared database.
final storeProvider = Provider<LedgerStore>((ref) {
  return DriftLedgerStore(ref.watch(ledgerDatabaseProvider));
});

/// Builds the sync metadata store around the same shared database, so a later
/// picker controller can take [SyncMetadataStore] without a second database.
final syncMetadataStoreProvider = Provider<SyncMetadataStore>((ref) {
  return SyncMetadataStore(ref.watch(ledgerDatabaseProvider));
});

final bannerStateProvider = ChangeNotifierProvider<BannerState>((ref) {
  return BannerState();
});

final analysisCacheProvider = ChangeNotifierProvider<AnalysisCache>((ref) {
  return AnalysisCache();
});

/// Joins the analysis cache to the ledger's bus as soon as boot reaches
/// `Ready`.
// This must happen synchronously, since nothing can run between reaching
// `Ready` and [AppBoot.start]'s first mutate.
final appBootProvider = ChangeNotifierProvider<AppBoot>((ref) {
  final banner = ref.read(bannerStateProvider.notifier);
  final cache = ref.read(analysisCacheProvider.notifier);

  final boot = AppBoot(
    createStore: () async => ref.read(storeProvider),
    seedChanges: seedChanges,
    onSaveState: banner.receiveSaveState,
    onPlanError: banner.receivePlanErrors,
    // LazyDatabase caches a failed open, so all three providers need
    // invalidating or a retry just replays the same failure.
    onRetry: () {
      ref.invalidate(storeProvider);
      ref.invalidate(syncMetadataStoreProvider);
      ref.invalidate(ledgerDatabaseProvider);
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

/// Null outside [Ready], never a throw.
// A null callers can pattern match beats a null check pushed onto every
// caller.
final ledgerProvider = Provider<Ledger?>((ref) {
  final phase = ref.watch(appPhaseProvider);
  return phase is Ready ? phase.ledger : null;
});

final persistenceProcessorProvider = Provider<PersistenceProcessor?>((ref) {
  final phase = ref.watch(appPhaseProvider);
  return phase is Ready ? phase.persistence : null;
});
