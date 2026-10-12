part of 'drift_ledger_store.dart';

// MARK: - Ingest

extension _DriftStoreIngest on DriftLedgerStore {
  void _drain() {
    if (_ingest.isEmpty) return;
    var buffered = false;
    while (_ingest.isNotEmpty) {
      final item = _ingest.removeFirst();
      if (item is _Barrier) {
        item.reached.complete();
        continue;
      }
      _pending.addAll(item as List<_StampedChange>);
      buffered = true;
    }
    if (buffered) _armDebounce();
  }

  void _armDebounce() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _retryTimer = null;
    _debounceTimer = _armTimer(_debounce, () {
      _debounceTimer = null;
      unawaited(_saveCycle());
    });
  }
}

// MARK: - Save Cycle

extension _DriftStoreSaving on DriftLedgerStore {
  void _report(SaveBannerState state) {
    final isClear = state == SaveBannerState.clear;
    if (isClear && !_reportedNonClear) return;
    _reportedNonClear = !isClear;
    _handler?.call(state);
  }

  Future<void> _saveCycle() {
    final running = _inFlightSave;
    if (running != null) return running;

    final cycle = _runCycle();
    _inFlightSave = cycle;
    return cycle.whenComplete(() => _inFlightSave = null);
  }

  Future<void> _runCycle() async {
    _lastCycleGaveUp = false;
    _lastFailure = null;
    _lastFailureStack = null;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      if (_pending.isEmpty && !_seedFlagPending) return;

      final taken = _pending.length;
      final coalesced = _coalesce(_pending.sublist(0, taken));

      final seedingThisCycle = _seedFlagPending;

      try {
        await db.transaction(() async {
          for (final write in coalesced) {
            await _apply(write);
          }
          if (seedingThisCycle) await _writeSeedFlag();
        });
      } on PermanentSaveError catch (error, stackTrace) {
        _lastCycleGaveUp = true;
        _lastFailure = error;
        _lastFailureStack = stackTrace;
        _report(SaveBannerState.permanentlyFailed);
        return;
      } on Object catch (error, stackTrace) {
        if (attempt < _maxRetries) {
          if (!_inTimedRetry) _report(SaveBannerState.retrying);
          await _wait(_retryBackoff);
          continue;
        }
        _lastCycleGaveUp = true;
        _lastFailure = error;
        _lastFailureStack = stackTrace;
        _report(SaveBannerState.failedWillRetry);
        _armTimedRetry();
        return;
      }

      _pending.removeRange(0, taken);
      if (seedingThisCycle) _seedFlagPending = false;
      _report(SaveBannerState.clear);
      return;
    }
  }

  void _armTimedRetry() {
    _retryTimer?.cancel();
    _retryTimer = _armTimer(_retryBackoff, () {
      _retryTimer = null;
      _inTimedRetry = true;
      unawaited(_saveCycle().whenComplete(() => _inTimedRetry = false));
    });
  }

  Future<void> _wait(Duration delay) {
    final completer = Completer<void>();
    _armTimer(delay, completer.complete);
    return completer.future;
  }
}
