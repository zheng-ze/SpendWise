import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/period_summary.dart';
import 'package:spendwise/ledger/analysis/today_summary.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';

class AnalysisQueries extends ChangeNotifier {
  AnalysisQueries({
    required Ledger ledger,
    required AnalysisCache cache,
    required DateTime today,
  }) : _today = startOfDayUtc(today) {
    _ledger = ledger;
    _cache = cache;
    _publishedStamp = _cache.itemsSourceRevision;
    _ledger.addListener(_onLedgerChanged);
    _cache.addListener(_onCacheChanged);
    _requestRefresh();
  }

  late final Ledger _ledger;

  late final AnalysisCache _cache;

  DateTime _today;

  late int _publishedStamp;

  bool _disposed = false;

  final Map<String, _Stored> _stored = {};

  final Set<String> _failedEvaluations = {};

  final Set<Future<void>> _observed = {};

  final Set<int> _inflight = {};

  void setToday(DateTime today) {
    final day = startOfDayUtc(today);
    if (day == _today) return;
    _today = day;
    if (_disposed) return;
    if (_cache.itemsSourceRevision == _ledger.revision) {
      notifyListeners();
    }
  }

  Future<void> retry() {
    _failedEvaluations.clear();
    if (_disposed) return Future.value();
    return _requestRefresh();
  }

  AnalysisQueryResult<TodaySummary> readToday() {
    return _readMixed<TodaySummary>(
      'today',
      () => todaySummary(
        ledger: _ledger.state,
        items: _cache.items,
        today: _today,
      ),
    );
  }

  AnalysisQueryResult<PeriodSummary> readPeriod({
    required DateRange window,
    Set<String>? sourceIDs,
  }) {
    final start = startOfDayUtc(window.start);
    final end = startOfDayUtc(window.end);
    final scope = sourceIDs == null
        ? 'all'
        : 'scope:${(sourceIDs.map(normalizedID).toSet().toList()..sort()).join(',')}';
    return _readMixed<PeriodSummary>(
      'period|${start.toIso8601String()}|${end.toIso8601String()}|$scope',
      () => periodSummary(
        ledger: _ledger.state,
        items: _cache.items,
        today: _today,
        window: window,
        sourceIDs: sourceIDs,
      ),
    );
  }

  AnalysisQueryResult<T> _readMixed<T>(String identity, T Function() evaluate) {
    final revision = _ledger.revision;
    final stamp = _cache.itemsSourceRevision;
    final key = '$identity|${_today.toIso8601String()}|$revision|$stamp';
    final stored = _stored[identity];
    if (stored != null && stored.key == key) {
      return stored.result as AnalysisQueryResult<T>;
    }
    if (stamp == revision && !_failedEvaluations.contains(key)) {
      try {
        final result = AnalysisQueryResult<T>(
          value: evaluate(),
          state: AnalysisQueryState.ready,
          sourceRevision: revision,
        );
        _stored[identity] = _Stored(key, result);
        return result;
      } catch (_) {
        _failedEvaluations.add(key);
      }
    }
    final previous = stored?.result as AnalysisQueryResult<T>?;
    final state = _failedEvaluations.contains(key)
        ? AnalysisQueryState.failed
        : _pendingState(revision);
    if (previous != null) {
      return AnalysisQueryResult<T>(
        value: previous.value,
        state: state,
        sourceRevision: previous.sourceRevision,
      );
    }
    return AnalysisQueryResult<T>(
      value: null,
      state: state,
      sourceRevision: null,
    );
  }

  AnalysisQueryState _pendingState(int revision) {
    if (_inflight.contains(revision)) return AnalysisQueryState.loading;
    final failure = _cache.lastFailure;
    if (failure != null && failure.sourceRevision == revision) {
      return AnalysisQueryState.failed;
    }
    return AnalysisQueryState.loading;
  }

  void _onLedgerChanged() {
    if (_disposed) return;
    unawaited(_requestRefresh());
  }

  void _onCacheChanged() {
    if (_disposed) return;
    final stamp = _cache.itemsSourceRevision;
    if (stamp != _ledger.revision || stamp == _publishedStamp) return;
    _publishedStamp = stamp;
    notifyListeners();
  }

  Future<void> _requestRefresh() {
    if (_disposed) return Future.value();
    final request = _ledger.revision;
    final future = _cache.refresh(_ledger.state);
    if (_observed.add(future)) {
      _inflight.add(request);
      future.then((_) {
        _observed.remove(future);
        _inflight.remove(request);
        if (_disposed) return;
        if (_cache.itemsSourceRevision == _ledger.revision) return;
        final failure = _cache.lastFailure;
        if (failure != null &&
            failure.sourceRevision == request &&
            request == _ledger.revision) {
          notifyListeners();
        }
      });
    }
    return future;
  }

  @override
  void dispose() {
    _disposed = true;
    _ledger.removeListener(_onLedgerChanged);
    _cache.removeListener(_onCacheChanged);
    _stored.clear();
    _failedEvaluations.clear();
    _observed.clear();
    _inflight.clear();
    super.dispose();
  }
}

class _Stored {
  _Stored(this.key, this.result);

  final String key;

  final AnalysisQueryResult<dynamic> result;
}
