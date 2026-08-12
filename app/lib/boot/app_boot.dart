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

  Future<void> start() async {
    await _teardown();
    _setPhase(const Loading());

    try {
      final store = await createStore();
      await store.setErrorHandler(_handleSaveState);
      await store.seedIfFirstLaunch(seedChanges());

      final state = await store.load();

      final bus = _bus = EventBus();
      final persistence = PersistenceProcessor(store: store, bus: bus);
      await persistence.start();

      final ledger = Ledger(state: state, bus: bus);
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

  /// Flush must precede disposal or a retry drops the pending writes. The bus
  /// close stays outside the phase guard, since a boot that failed after minting
  /// one leaves it behind with no `Ready` to reach it through.
  Future<void> _teardown() async {
    final phase = _phase;
    if (phase is Ready) {
      await phase.persistence.flush();
      await phase.persistence.dispose();
      phase.ledger.dispose();
    }

    await _bus?.dispose();
    _bus = null;
  }

  @override
  void dispose() {
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
