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
    DateTime Function()? now,
  }) : now = now ?? _utcNow;

  /// An instant, not a calendar day, so it is not normalized to UTC midnight.
  /// A device-local one would make occurrence identity vary by timezone.
  final DateTime Function() now;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final StoreFactory createStore;

  final SeedBuilder seedChanges;

  final SaveErrorHandler? onSaveState;

  final PlanErrorHandler? onPlanError;

  AppPhase _phase = const Loading();

  AppPhase get phase => _phase;

  EventBus? _bus;

  /// Tracks whatever the current attempt has wired so far, independent of
  /// phase. A throw after wiring but before (or after) reaching `Ready` still
  /// leaves something here for `_teardown` to find and dispose.
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

  Future<void> retry() => start();

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
        unawaited(phase.persistence.flush());
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Flush must precede disposal or a retry drops the pending writes. This
  /// runs off the tracked wiring fields rather than `phase is Ready`, since a
  /// throw partway through `start()` can leave persistence and the ledger
  /// wired with no `Ready` phase ever reaching them, or a `Ready` reached and
  /// then overwritten by a later throw in the same attempt.
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

  /// `ChangeNotifier.dispose()` is synchronous, so the `dispose()` override
  /// below cannot await the flush and is best-effort: a container torn down
  /// right as the app exits can still drop a pending write. A caller that
  /// controls its own shutdown sequence and can await should call this
  /// instead, ahead of whatever disposes the provider, to get a guaranteed
  /// flush. Either path marks the notifier disposed, so the provider's own
  /// later `dispose()` call (Riverpod always makes one) becomes a no-op
  /// instead of disposing a `ChangeNotifier` twice.
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
    unawaited(_teardown());
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
