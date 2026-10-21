part of 'analysis_queries.dart';

// MARK: - Summaries

extension _AnalysisMixedReads on AnalysisQueries {
  AnalysisQueryResult<TodaySummary> _readToday() {
    return _readMixed<TodaySummary>(
      'today',
      () => todaySummary(
        ledger: _ledger.state,
        items: _cache.items,
        today: _today,
      ),
    );
  }

  AnalysisQueryResult<PeriodSummary> _readPeriod({
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

  AnalysisQueryResult<List<WeekTotal>> _readWeeks({
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

  // MARK: - Spreads

  AnalysisQueryResult<MonthSpread> _readMonthSpread({
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

  AnalysisQueryResult<YearSpread> _readYearSpread({
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

  AnalysisQueryResult<MonthTrendsPeriod> _readTrendsPeriod({
    required DateTime endMonth,
    required CategoryKind kind,
    required BreakdownLevel level,
  }) {
    final anchor = monthWindow(endMonth).start;
    final identity =
        'trends-period|month|${anchor.toIso8601String()}|'
        '${kind.name}|${level.name}';
    return _readMixed<MonthTrendsPeriod>(identity, () {
      if (anchor.isAfter(monthWindow(_today).start)) {
        throw ArgumentError.value(
          endMonth,
          'endMonth',
          'Month is in the future.',
        );
      }
      return trendsPeriod(
        items: _cache.items,
        state: _ledger.state,
        endMonth: anchor,
        kind: kind,
        level: level,
        today: _today,
      );
    });
  }

  // MARK: - Breakdowns

  AnalysisQueryResult<PeriodBreakdown> _readCategoryBreakdown({
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

  AnalysisQueryResult<ScopedTrend> _readScopedTrend({
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

  AnalysisQueryResult<ComparedWithUsual> _readComparedWithUsual({
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

  // MARK: - Insights

  AnalysisQueryResult<MatchedDayInsights> _readMatchedDayInsights() {
    return _readMixed<MatchedDayInsights>(
      'matched-day-insights',
      () => matchedDayInsights(
        items: _cache.items,
        state: _ledger.state,
        firstRecordMonth: firstRecordMonth(_ledger.state),
        today: _today,
        rules: _rules,
      ),
    );
  }

  AnalysisQueryResult<WeekSoFar> _readWeekSoFar() {
    return _readMixed<WeekSoFar>(
      'week-so-far',
      () => weekSoFar(
        items: _cache.items,
        firstRecordMonth: firstRecordMonth(_ledger.state),
        today: _today,
        rules: _rules,
      ),
    );
  }

  // MARK: - Budgets

  AnalysisQueryResult<BudgetsOverview> _readBudgets({required DateTime month}) {
    final anchor = monthWindow(month).start;
    return _readMixed<BudgetsOverview>(
      'budgets|${anchor.toIso8601String()}',
      () => budgetsOverview(
        state: _ledger.state,
        items: _cache.items,
        month: YearMonth(anchor.year, anchor.month),
        today: _today,
      ),
    );
  }

  AnalysisQueryResult<BudgetDetail> _readBudgetDetail({
    required String budgetID,
    required DateTime displayedYear,
    required DateTime selectedMonth,
  }) {
    final id = normalizedID(budgetID);
    final year = startOfDayUtc(displayedYear).year;
    final anchor = monthWindow(selectedMonth).start;
    return _readMixed<BudgetDetail>(
      'budget-detail|$id|$year|${anchor.toIso8601String()}',
      () => budgetDetail(
        state: _ledger.state,
        items: _cache.items,
        budgetID: id,
        displayedYear: year,
        selectedMonth: YearMonth(anchor.year, anchor.month),
        today: _today,
      ),
    );
  }
}
