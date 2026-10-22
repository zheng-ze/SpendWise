import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_detail.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_overview.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/summaries/calendar.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/breakdowns/compared_with_usual.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';
import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis/insights/insight_rules.dart';
import 'package:spendwise/ledger/analysis/insights/matched_day_insights.dart';
import 'package:spendwise/ledger/analysis/summaries/month_spread.dart';
import 'package:spendwise/ledger/analysis/summaries/period_summary.dart';
import 'package:spendwise/ledger/analysis/summaries/register.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/search.dart';
import 'package:spendwise/ledger/analysis/summaries/today_summary.dart';
import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';
import 'package:spendwise/ledger/analysis/summaries/upcoming.dart';
import 'package:spendwise/ledger/analysis/summaries/week_so_far.dart';
import 'package:spendwise/ledger/analysis/summaries/weeks.dart';
import 'package:spendwise/ledger/analysis/summaries/year_spread.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';

// MARK: - Parts

part 'analysis_queries_ledger_reads.dart';
part 'analysis_queries_mixed_reads.dart';

// MARK: - Configuration

const int _maxRetainedIdentities = 256;

// MARK: - Queries

class AnalysisQueries extends ChangeNotifier {
  AnalysisQueries({
    required Ledger ledger,
    required AnalysisCache cache,
    required DateTime today,
    InsightRules? rules,
  }) : _today = startOfDayUtc(today),
       _rules = rules ?? InsightRules.defaults {
    _ledger = ledger;
    _cache = cache;
    _publishedStamp = _cache.itemsSourceRevision;
    _ledger.addListener(_onLedgerChanged);
    _cache.addListener(_onCacheChanged);
    _requestRefresh();
  }

  late final Ledger _ledger;

  late final AnalysisCache _cache;

  final InsightRules _rules;

  DateTime _today;

  late int _publishedStamp;

  bool _disposed = false;

  final Map<String, _Stored> _stored = {};

  final Set<String> _failedEvaluations = {};

  final Set<Future<void>> _observed = {};

  final Set<int> _inflight = {};

  // MARK: - Lifecycle

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

  // MARK: - Reads

  AnalysisQueryResult<List<RegisterDay>> readRegisterDays({
    required DateRange window,
    Set<String>? sourceIDs,
    EntryKind? kind,
  }) => _readRegisterDays(window: window, sourceIDs: sourceIDs, kind: kind);

  AnalysisQueryResult<List<EntryRecord>> readRecent({
    int limit = 4,
    Set<String>? sourceIDs,
  }) => _readRecent(limit: limit, sourceIDs: sourceIDs);

  AnalysisQueryResult<List<UpcomingItem>> readUpcoming({
    DateRange? window,
    Set<String>? sourceIDs,
  }) => _readUpcoming(window: window, sourceIDs: sourceIDs);

  AnalysisQueryResult<List<SearchMonth>> readSearch({
    required String query,
    DateRange? window,
    Set<String>? sourceIDs,
    EntryKind? kind,
  }) => _readSearch(
    query: query,
    window: window,
    sourceIDs: sourceIDs,
    kind: kind,
  );

  AnalysisQueryResult<List<CalendarDay>> readCalendarDays({
    required DateRange window,
    Set<String>? sourceIDs,
  }) => _readCalendarDays(window: window, sourceIDs: sourceIDs);

  AnalysisQueryResult<CardStatement?> readCardStatement({
    required String accountID,
  }) => _readCardStatement(accountID: accountID);

  AnalysisQueryResult<DateTime?> readFirstRecordMonth() =>
      _readFirstRecordMonth();

  AnalysisQueryResult<PeriodCompletenessResult> readMonthCompleteness({
    required DateTime month,
  }) => _readMonthCompleteness(month: month);

  AnalysisQueryResult<PeriodCompletenessResult> readWeekCompleteness({
    required DateTime containingDay,
  }) => _readWeekCompleteness(containingDay: containingDay);

  AnalysisQueryResult<TodaySummary> readToday() => _readToday();

  AnalysisQueryResult<PeriodSummary> readPeriod({
    required DateRange window,
    Set<String>? sourceIDs,
  }) => _readPeriod(window: window, sourceIDs: sourceIDs);

  AnalysisQueryResult<List<WeekTotal>> readWeeks({
    required DateRange window,
    Set<String>? sourceIDs,
  }) => _readWeeks(window: window, sourceIDs: sourceIDs);

  AnalysisQueryResult<MonthSpread> readMonthSpread({
    required DateTime endMonth,
    required CategoryKind kind,
  }) => _readMonthSpread(endMonth: endMonth, kind: kind);

  AnalysisQueryResult<YearSpread> readYearSpread({
    required int endYear,
    required CategoryKind kind,
  }) => _readYearSpread(endYear: endYear, kind: kind);

  AnalysisQueryResult<MonthTrendsPeriod> readTrendsPeriod({
    required DateTime endMonth,
    required CategoryKind kind,
    required BreakdownLevel level,
  }) => _readTrendsPeriod(endMonth: endMonth, kind: kind, level: level);

  AnalysisQueryResult<PeriodBreakdown> readCategoryBreakdown({
    required DateTime period,
    required AnalysisPeriodMode mode,
    required CategoryKind kind,
    required BreakdownLevel level,
  }) => _readCategoryBreakdown(
    period: period,
    mode: mode,
    kind: kind,
    level: level,
  );

  AnalysisQueryResult<ScopedTrend> readScopedTrend({
    required DateTime period,
    required AnalysisPeriodMode mode,
    required CategoryKind kind,
    required String? mainBucketID,
    required AnalysisCategoryScope scope,
  }) => _readScopedTrend(
    period: period,
    mode: mode,
    kind: kind,
    mainBucketID: mainBucketID,
    scope: scope,
  );

  AnalysisQueryResult<ComparedWithUsual> readComparedWithUsual({
    required DateTime month,
    required CategoryKind kind,
  }) => _readComparedWithUsual(month: month, kind: kind);

  AnalysisQueryResult<MatchedDayInsights> readMatchedDayInsights() =>
      _readMatchedDayInsights();

  AnalysisQueryResult<WeekSoFar> readWeekSoFar() => _readWeekSoFar();

  AnalysisQueryResult<BudgetsOverview> readBudgets({required DateTime month}) =>
      _readBudgets(month: month);

  AnalysisQueryResult<BudgetDetail> readBudgetDetail({
    required String budgetID,
    required DateTime displayedYear,
    required DateTime selectedMonth,
  }) => _readBudgetDetail(
    budgetID: budgetID,
    displayedYear: displayedYear,
    selectedMonth: selectedMonth,
  );

  // MARK: - Engine

  AnalysisQueryResult<T> _readLedgerOnly<T>(
    String identity,
    String key,
    T Function() evaluate,
  ) {
    final stored = _touch(identity);
    if (stored != null && stored.key == key) {
      return stored.result as AnalysisQueryResult<T>;
    }
    if (!_failedEvaluations.contains(key)) {
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
    if (stamp == revision && !_failedEvaluations.contains(key)) {
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

  void _recordFailure(String key) => _failedEvaluations.add(key);

  AnalysisQueryState _pendingState(int revision) {
    if (_inflight.contains(revision)) return AnalysisQueryState.loading;
    final failure = _cache.lastFailure;
    if (failure != null && failure.sourceRevision == revision) {
      return AnalysisQueryState.failed;
    }
    return AnalysisQueryState.loading;
  }

  // MARK: - Helpers

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

  // MARK: - Refresh

  void _onLedgerChanged() {
    if (_disposed) return;
    _failedEvaluations.clear();
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

// MARK: - Stored Results

class _Stored {
  _Stored(this.key, this.result);

  final String key;

  final AnalysisQueryResult<dynamic> result;
}
