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

final databaseConnectionProvider = Provider<Future<QueryExecutor>>((ref) {
  return openLedgerConnection();
});

final ledgerDatabaseProvider = Provider<LedgerDatabase>((ref) {
  final database = LedgerDatabase(
    LazyDatabase(() => ref.read(databaseConnectionProvider)),
  );
  ref.onDispose(() => database.close().catchError((_) {}));
  return database;
});

final storeProvider = Provider<LedgerStore>((ref) {
  return DriftLedgerStore(ref.watch(ledgerDatabaseProvider));
});

final syncMetadataStoreProvider = Provider<SyncMetadataStore>((ref) {
  return SyncMetadataStore(ref.watch(ledgerDatabaseProvider));
});

final bannerStateProvider = ChangeNotifierProvider<BannerState>((ref) {
  return BannerState();
});

final analysisCacheProvider = ChangeNotifierProvider<AnalysisCache>((ref) {
  return AnalysisCache();
});

final appBootProvider = ChangeNotifierProvider<AppBoot>((ref) {
  final banner = ref.read(bannerStateProvider.notifier);
  final cache = ref.read(analysisCacheProvider.notifier);

  final boot = AppBoot(
    createStore: () async => ref.read(storeProvider),
    seedChanges: seedChanges,
    onSaveState: banner.receiveSaveState,
    onPlanError: banner.receivePlanErrors,
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

final ledgerProvider = Provider<Ledger?>((ref) {
  final phase = ref.watch(appPhaseProvider);
  return phase is Ready ? phase.ledger : null;
});

final persistenceProcessorProvider = Provider<PersistenceProcessor?>((ref) {
  final phase = ref.watch(appPhaseProvider);
  return phase is Ready ? phase.persistence : null;
});
