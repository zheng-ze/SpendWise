import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';

import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

typedef StoreFactory = Future<LedgerStore> Function();

typedef SeedBuilder = List<LedgerChange> Function();

typedef SyncSnapshotReader = Future<SyncMetadataSnapshot> Function();

class AppBoot extends ChangeNotifier with WidgetsBindingObserver {
  AppBoot({
    required this.createStore,
    required this.seedChanges,
    this.readSyncSnapshot,
    this.onSaveState,
    this.onPlanError,
    this.onRetry,
    DateTime Function()? now,
  }) : now = now ?? utcNowFor;

  /// Always UTC, never device-local time.
  final DateTime Function() now;

  @visibleForTesting
  static DateTime utcNowFor([DateTime? localNow]) =>
      startOfDayUtc(localNow ?? DateTime.now());

  final StoreFactory createStore;

  final SeedBuilder seedChanges;

  final SyncSnapshotReader? readSyncSnapshot;

  final SaveErrorHandler? onSaveState;

  final PlanErrorHandler? onPlanError;

  final void Function()? onRetry;

  AppPhase _phase = const Loading();

  AppPhase get phase => _phase;

  EventBus? _bus;

  // A mid-start throw can wire persistence without reaching Ready.
  PersistenceProcessor? _persistence;

  Ledger? _ledger;

  HostedSyncStatus _syncStatus = const HostedSyncUnavailable();

  HostedSyncStatus get syncStatus => _syncStatus;

  int _statusGeneration = 0;

  Future<void> start() async {
    final generation = ++_statusGeneration;
    await _teardown();
    _syncStatus = const HostedSyncUnavailable();
    _setPhase(const Loading());

    try {
      final store = await createStore();
      await store.setErrorHandler(_handleSaveState);
      await store.seedIfFirstLaunch(seedChanges());

      final state = await store.load();
      await _loadSyncStatus(generation);

      final bus = _bus = EventBus();
      final persistence = _persistence = PersistenceProcessor(
        store: store,
        bus: bus,
      );
      await persistence.start();

      final ledger = _ledger = Ledger(state: state, bus: bus);
      ledger.onPlanError = _handlePlanError;

      _setPhase(Ready(ledger: ledger, persistence: persistence));

      // No resume event fires for the initial launch.
      ledger.resolvePlans(now());
    } catch (error, stackTrace) {
      _setPhase(Failed(error, stackTrace));
    }
  }

  Future<void> retry() {
    onRetry?.call();
    return start();
  }

  Future<void> refreshSyncStatus() {
    final generation = ++_statusGeneration;
    return _loadSyncStatus(generation);
  }

  // A status-read failure must never block ledger readiness, so decode and
  // read errors project to unavailable instead of throwing.
  Future<void> _loadSyncStatus(int generation) async {
    final reader = readSyncSnapshot;
    if (reader == null) return;
    HostedSyncStatus projected;
    try {
      projected = projectHostedSyncStatus(await reader());
    } catch (_) {
      projected = const HostedSyncUnavailable();
    }
    if (generation != _statusGeneration) return;
    _syncStatus = projected;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final phase = _phase;
    if (phase is! Ready) return;

    switch (state) {
      case AppLifecycleState.resumed:
        phase.ledger.resolvePlans(now());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(
          phase.persistence.flush().catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            debugPrint(
              'AppBoot backgrounding flush failed: $error\n$stackTrace',
            );
          }),
        );
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _teardown() async {
    final persistence = _persistence;
    if (persistence != null) {
      try {
        await persistence.flush();
      } catch (error, stackTrace) {
        debugPrint('AppBoot teardown flush failed: $error\n$stackTrace');
      }
      await persistence.dispose();
    }
    _ledger?.dispose();
    _persistence = null;
    _ledger = null;

    await _bus?.dispose();
    _bus = null;
  }

  bool _disposed = false;

  // dispose cannot await; flush here first.
  Future<void> disposeAndFlush() async {
    if (_disposed) return;
    _disposed = true;
    await _teardown();
    super.dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(
      _teardown().catchError((Object error, StackTrace stackTrace) {
        debugPrint('AppBoot dispose teardown failed: $error\n$stackTrace');
      }),
    );
    super.dispose();
  }

  void _handleSaveState(SaveBannerState state) => onSaveState?.call(state);

  void _handlePlanError(List<PlanFailure> failures) =>
      onPlanError?.call(failures);

  void _setPhase(AppPhase phase) {
    _phase = phase;
    notifyListeners();
  }
}
