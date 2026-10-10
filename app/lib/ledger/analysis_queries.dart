import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/calendar.dart';
import 'package:spendwise/ledger/analysis/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/compared_with_usual.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis/month_spread.dart';
import 'package:spendwise/ledger/analysis/period_summary.dart';
import 'package:spendwise/ledger/analysis/register.dart';
import 'package:spendwise/ledger/analysis/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/search.dart';
import 'package:spendwise/ledger/analysis/today_summary.dart';
import 'package:spendwise/ledger/analysis/upcoming.dart';
import 'package:spendwise/ledger/analysis/weeks.dart';
import 'package:spendwise/ledger/analysis/year_spread.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';

const int _maxRetainedIdentities = 16;

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

  final Map<String, int> _failedEvaluations = {};

  final Set<Future<void>> _observed = {};

  final Set<int> _inflight = {};

  void setToday(DateTime today) {
    final day = startOfDayUtc(today);
    if (day == _today) return;
    _today = day;
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> retry() {
    _failedEvaluations.clear();
    if (_disposed) return Future.value();
    final wasInflight = _inflight.contains(_ledger.revision);
    final refresh = _requestRefresh();
    if (!wasInflight && _inflight.contains(_ledger.revision)) {
      notifyListeners();
    }
    return refresh;
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
        window: window,
        sourceIDs: sourceIDs,
      ),
    );
  }

  AnalysisQueryResult<List<RegisterDay>> readRegisterDays({
    required DateRange window,
    Set<String>? sourceIDs,
    EntryKind? kind,
  }) {
    final start = startOfDayUtc(window.start);
    final end = startOfDayUtc(window.end);
    final identity =
        'register|${start.toIso8601String()}|${end.toIso8601String()}|'
        '${_scopeIdentity(sourceIDs)}|${kind?.name ?? 'any'}';
    return _readLedgerOnly<List<RegisterDay>>(
      identity,
      '$identity|${_ledger.revision}',
      () => registerDays(
        ledger: _ledger.state,
        window: window,
        sourceIDs: sourceIDs,
        kind: kind,
      ),
    );
  }

  AnalysisQueryResult<List<EntryRecord>> readRecent({
    int limit = 4,
    Set<String>? sourceIDs,
  }) {
    final identity = 'recent|$limit|${_scopeIdentity(sourceIDs)}';
    return _readLedgerOnly<List<EntryRecord>>(
      identity,
      '$identity|${_today.toIso8601String()}|${_ledger.revision}',
      () => recentEntries(
        ledger: _ledger.state,
        today: _today,
        limit: limit,
        sourceIDs: sourceIDs,
      ),
    );
  }

  AnalysisQueryResult<List<UpcomingItem>> readUpcoming({
    DateRange? window,
    Set<String>? sourceIDs,
  }) {
    final resolved =
        window ?? DateRange(_today, _today.add(const Duration(days: 42)));
    final start = startOfDayUtc(resolved.start);
    final end = startOfDayUtc(resolved.end);
    final identity =
        'upcoming|${start.toIso8601String()}|${end.toIso8601String()}|'
        '${_scopeIdentity(sourceIDs)}';
    return _readLedgerOnly<List<UpcomingItem>>(
      identity,
      '$identity|${_today.toIso8601String()}|${_ledger.revision}',
      () => upcomingItems(
        ledger: _ledger.state,
        today: _today,
        window: resolved,
        sourceIDs: sourceIDs,
      ),
    );
  }

  AnalysisQueryResult<List<WeekTotal>> readWeeks({
    required DateRange window,
    Set<String>? sourceIDs,
  }) {
    final start = startOfDayUtc(window.start);
    final end = startOfDayUtc(window.end);
    final scope = sourceIDs == null
        ? 'all'
        : 'scope:${(sourceIDs.map(normalizedID).toSet().toList()..sort()).join(',')}';
    return _readMixed<List<WeekTotal>>(
      'weeks|${start.toIso8601String()}|${end.toIso8601String()}|$scope',
      () => weekTotals(
        ledger: _ledger.state,
        items: _cache.items,
        window: window,
        sourceIDs: sourceIDs,
      ),
    );
  }

  AnalysisQueryResult<List<SearchMonth>> readSearch({
    required String query,
    DateRange? window,
    Set<String>? sourceIDs,
    EntryKind? kind,
  }) {
    final needle = query.trim().toLowerCase();
    final range = window == null
        ? 'any'
        : '${startOfDayUtc(window.start).toIso8601String()}|'
              '${startOfDayUtc(window.end).toIso8601String()}';
    final identity =
        'search|$needle|$range|${_scopeIdentity(sourceIDs)}|'
        '${kind?.name ?? 'any'}';
    return _readLedgerOnly<List<SearchMonth>>(
      identity,
      '$identity|${_ledger.revision}',
      () => searchEntries(
        ledger: _ledger.state,
        query: query,
        window: window,
        sourceIDs: sourceIDs,
        kind: kind,
      ),
    );
  }

  AnalysisQueryResult<List<CalendarDay>> readCalendarDays({
    required DateRange window,
    Set<String>? sourceIDs,
  }) {
    final start = startOfDayUtc(window.start);
    final end = startOfDayUtc(window.end);
    final identity =
        'calendar|${start.toIso8601String()}|${end.toIso8601String()}|'
        '${_scopeIdentity(sourceIDs)}';
    return _readLedgerOnly<List<CalendarDay>>(
      identity,
      '$identity|${_today.toIso8601String()}|${_ledger.revision}',
      () => calendarDays(
        ledger: _ledger.state,
        today: _today,
        window: window,
        sourceIDs: sourceIDs,
      ),
    );
  }

  AnalysisQueryResult<CardStatement?> readCardStatement({
    required String accountID,
  }) {
    final id = normalizedID(accountID);
    final identity = 'card|$id';
    return _readLedgerOnly<CardStatement?>(
      identity,
      '$identity|${_today.toIso8601String()}|${_ledger.revision}',
      () => cardStatement(ledger: _ledger.state, accountID: id, today: _today),
    );
  }

  AnalysisQueryResult<DateTime?> readFirstRecordMonth() {
    const identity = 'first-record-month';
    return _readLedgerOnly<DateTime?>(
      identity,
      '$identity|${_ledger.revision}',
      () => firstRecordMonth(_ledger.state),
    );
  }

  AnalysisQueryResult<PeriodCompletenessResult> readMonthCompleteness({
    required DateTime month,
  }) {
    final window = monthWindow(month);
    final identity = 'month-completeness|${window.start.toIso8601String()}';
    return _readLedgerOnly<PeriodCompletenessResult>(
      identity,
      '$identity|${_today.toIso8601String()}|${_ledger.revision}',
      () => _completeness(window),
    );
  }

  AnalysisQueryResult<PeriodCompletenessResult> readWeekCompleteness({
    required DateTime containingDay,
  }) {
    final window = weekWindow(containingDay);
    final identity = 'week-completeness|${window.start.toIso8601String()}';
    return _readLedgerOnly<PeriodCompletenessResult>(
      identity,
      '$identity|${_today.toIso8601String()}|${_ledger.revision}',
      () => _completeness(window),
    );
  }

  AnalysisQueryResult<MonthSpread> readMonthSpread({
    required DateTime endMonth,
    required CategoryKind kind,
  }) {
    final anchor = monthWindow(endMonth).start;
    return _readMixed<MonthSpread>(
      'month-spread|${anchor.toIso8601String()}|${kind.name}',
      () {
        if (anchor.isAfter(monthWindow(_today).start)) {
          throw ArgumentError.value(
            endMonth,
            'endMonth',
            'Month is in the future.',
          );
        }
        return monthSpread(
          items: _cache.items,
          endMonth: anchor,
          kind: kind,
          firstRecordMonth: firstRecordMonth(_ledger.state),
          today: _today,
        );
      },
    );
  }

  AnalysisQueryResult<YearSpread> readYearSpread({
    required int endYear,
    required CategoryKind kind,
  }) {
    return _readMixed<YearSpread>('year-spread|$endYear|${kind.name}', () {
      final currentYear = startOfDayUtc(_today).year;
      if (endYear > currentYear) {
        throw ArgumentError.value(endYear, 'endYear', 'Year is in the future.');
      }
      return yearSpread(
        items: _cache.items,
        endYear: endYear,
        kind: kind,
        firstRecordMonth: firstRecordMonth(_ledger.state),
        today: _today,
      );
    });
  }

  AnalysisQueryResult<PeriodBreakdown> readCategoryBreakdown({
    required DateTime period,
    required AnalysisPeriodMode mode,
    required CategoryKind kind,
    required BreakdownLevel level,
  }) {
    final day = startOfDayUtc(period);
    final window = switch (mode) {
      AnalysisPeriodMode.month => monthWindow(day),
      AnalysisPeriodMode.year => DateRange(
        DateTime.utc(day.year, 1, 1),
        DateTime.utc(day.year + 1, 1, 1),
      ),
    };
    return _readMixed<PeriodBreakdown>(
      'breakdown|${mode.name}|${window.start.toIso8601String()}|'
      '${kind.name}|${level.name}',
      () => categoryBreakdown(
        items: _cache.items,
        state: _ledger.state,
        window: window,
        kind: kind,
        level: level,
      ),
    );
  }

  AnalysisQueryResult<ScopedTrend> readScopedTrend({
    required DateTime period,
    required AnalysisPeriodMode mode,
    required CategoryKind kind,
    required String? mainBucketID,
    required AnalysisCategoryScope scope,
  }) {
    final day = startOfDayUtc(period);
    final anchor = scopedTrendAnchor(day, mode);
    final main = normalizedOptionalID(mainBucketID);
    final mainIdentity = main == null ? 'uncategorized' : 'bucket:$main';
    final scopeIdentity = switch (scope) {
      AllCategoryScope() => 'all',
      DirectCategoryScope() => 'direct',
      SubCategoryScope(:final subID) => 'sub:$subID',
    };
    return _readMixed<ScopedTrend>(
      'scoped-trend|${mode.name}|${anchor.toIso8601String()}|'
      '${kind.name}|$mainIdentity|$scopeIdentity',
      () => scopedTrend(
        mainBucketID: main,
        scope: scope,
        kind: kind,
        period: day,
        mode: mode,
        today: _today,
        state: _ledger.state,
        items: _cache.items,
      ),
    );
  }

  AnalysisQueryResult<ComparedWithUsual> readComparedWithUsual({
    required DateTime month,
    required CategoryKind kind,
  }) {
    final anchor = monthWindow(month).start;
    return _readMixed<ComparedWithUsual>(
      'compared-with-usual|${anchor.toIso8601String()}|${kind.name}',
      () {
        if (anchor.isAfter(monthWindow(_today).start)) {
          throw ArgumentError.value(month, 'month', 'Month is in the future.');
        }
        return comparedWithUsual(
          items: _cache.items,
          selectedMonth: anchor,
          kind: kind,
          firstRecordMonth: firstRecordMonth(_ledger.state),
          today: _today,
        );
      },
    );
  }

  PeriodCompletenessResult _completeness(DateRange window) {
    final first = firstRecordMonth(_ledger.state);
    return PeriodCompletenessResult(
      window: window,
      firstRecordMonth: first,
      today: _today,
      state: classifyPeriod(
        window: window,
        firstRecordMonth: first,
        today: _today,
      ),
    );
  }

  String _scopeIdentity(Set<String>? sourceIDs) {
    if (sourceIDs == null) return 'all';
    final ids = sourceIDs.map(normalizedID).toSet().toList()..sort();
    return 'scope:${ids.join(',')}';
  }

  AnalysisQueryResult<T> _readLedgerOnly<T>(
    String identity,
    String key,
    T Function() evaluate,
  ) {
    final stored = _touch(identity);
    if (stored != null && stored.key == key) {
      return stored.result as AnalysisQueryResult<T>;
    }
    if (!_failedEvaluations.containsKey(key)) {
      try {
        final result = AnalysisQueryResult<T>(
          value: evaluate(),
          state: AnalysisQueryState.ready,
          sourceRevision: _ledger.revision,
        );
        _retain(identity, _Stored(key, result));
        return result;
      } catch (_) {
        _recordFailure(key);
      }
    }
    final previous = stored?.result as AnalysisQueryResult<T>?;
    if (previous != null) {
      return AnalysisQueryResult<T>(
        value: previous.value,
        state: AnalysisQueryState.failed,
        sourceRevision: previous.sourceRevision,
      );
    }
    return AnalysisQueryResult<T>(
      value: null,
      state: AnalysisQueryState.failed,
      sourceRevision: null,
    );
  }

  AnalysisQueryResult<T> _readMixed<T>(String identity, T Function() evaluate) {
    final revision = _ledger.revision;
    final stamp = _cache.itemsSourceRevision;
    final key = '$identity|${_today.toIso8601String()}|$revision|$stamp';
    final stored = _touch(identity);
    if (stored != null && stored.key == key) {
      return stored.result as AnalysisQueryResult<T>;
    }
    if (stamp == revision && !_failedEvaluations.containsKey(key)) {
      try {
        final result = AnalysisQueryResult<T>(
          value: evaluate(),
          state: AnalysisQueryState.ready,
          sourceRevision: revision,
        );
        _retain(identity, _Stored(key, result));
        return result;
      } catch (_) {
        _recordFailure(key);
      }
    }
    final previous = stored?.result as AnalysisQueryResult<T>?;
    final state = _failedEvaluations.containsKey(key)
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

  _Stored? _touch(String identity) {
    final stored = _stored.remove(identity);
    if (stored != null) _stored[identity] = stored;
    return stored;
  }

  void _retain(String identity, _Stored stored) {
    _stored[identity] = stored;
    while (_stored.length > _maxRetainedIdentities) {
      _stored.remove(_stored.keys.first);
    }
  }

  void _recordFailure(String key) {
    final revision = _ledger.revision;
    _failedEvaluations.removeWhere((_, failedAt) => failedAt != revision);
    _failedEvaluations[key] = revision;
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
    notifyListeners();
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
