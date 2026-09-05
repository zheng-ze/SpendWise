import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';

import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/persistence_processor.dart';

typedef StoreFactory = Future<LedgerStore> Function();

typedef SeedBuilder = List<LedgerChange> Function();

class AppBoot extends ChangeNotifier with WidgetsBindingObserver {
  AppBoot({
    required this.createStore,
    required this.seedChanges,
    this.onSaveState,
    this.onPlanError,
    this.onRetry,
    DateTime Function()? now,
  }) : now = now ?? utcNowFor;

  /// Always UTC, never device-local time.
  // UTC keeps occurrence identity from varying by the device's timezone.
  final DateTime Function() now;

  /// Normalizes [localNow] (defaulting to the system clock) to UTC midnight
  /// of its own calendar day, never `.toUtc()`, which would shift the day for
  /// any positive UTC offset.
  @visibleForTesting
  static DateTime utcNowFor([DateTime? localNow]) =>
      startOfDayUtc(localNow ?? DateTime.now());

  final StoreFactory createStore;

  final SeedBuilder seedChanges;

  final SaveErrorHandler? onSaveState;

  final PlanErrorHandler? onPlanError;

  /// Clears the failed attempt's providers before [retry] calls [start] again.
  final void Function()? onRetry;

  AppPhase _phase = const Loading();

  AppPhase get phase => _phase;

  EventBus? _bus;

  // Tracked separately from phase so a throw during wiring still leaves
  // something for `_teardown` to dispose.
  PersistenceProcessor? _persistence;

  Ledger? _ledger;

  Future<void> start() async {
    await _teardown();
    _setPhase(const Loading());

    try {
      final store = await createStore();
      await store.setErrorHandler(_handleSaveState);
      await store.seedIfFirstLaunch(seedChanges());

      final state = await store.load();

      final bus = _bus = EventBus();
      final persistence = _persistence = PersistenceProcessor(
        store: store,
        bus: bus,
      );
      await persistence.start();

      final ledger = _ledger = Ledger(state: state, bus: bus);
      ledger.onPlanError = _handlePlanError;

      _setPhase(Ready(ledger: ledger, persistence: persistence));

      // The platform fires no resume for the initial launch.
      ledger.resolvePlans(now());
    } catch (error, stackTrace) {
      _setPhase(Failed(error, stackTrace));
    }
  }

  Future<void> retry() {
    onRetry?.call();
    return start();
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

  // Checks the tracked wiring fields, not `phase is Ready`, since a
  // mid-`start()` throw can wire persistence without ever reaching `Ready`.
  Future<void> _teardown() async {
    final persistence = _persistence;
    if (persistence != null) {
      await persistence.flush();
      await persistence.dispose();
    }
    _ledger?.dispose();
    _persistence = null;
    _ledger = null;

    await _bus?.dispose();
    _bus = null;
  }

  bool _disposed = false;

  /// Flushes pending writes and tears down, then calls the base [dispose].
  // Call this ahead of provider disposal. The synchronous dispose() override
  // below cannot await a flush, so this is the only path that guarantees one.
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
