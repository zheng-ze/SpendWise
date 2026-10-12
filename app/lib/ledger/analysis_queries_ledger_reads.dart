part of 'analysis_queries.dart';

// MARK: - Register

extension _AnalysisLedgerReads on AnalysisQueries {
  AnalysisQueryResult<List<RegisterDay>> _readRegisterDays({
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

  AnalysisQueryResult<List<EntryRecord>> _readRecent({
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

  AnalysisQueryResult<List<UpcomingItem>> _readUpcoming({
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

  // MARK: - Search

  AnalysisQueryResult<List<SearchMonth>> _readSearch({
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

  // MARK: - Calendar

  AnalysisQueryResult<List<CalendarDay>> _readCalendarDays({
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

  // MARK: - Statements

  AnalysisQueryResult<CardStatement?> _readCardStatement({
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

  AnalysisQueryResult<DateTime?> _readFirstRecordMonth() {
    const identity = 'first-record-month';
    return _readLedgerOnly<DateTime?>(
      identity,
      '$identity|${_ledger.revision}',
      () => firstRecordMonth(_ledger.state),
    );
  }

  // MARK: - Completeness

  AnalysisQueryResult<PeriodCompletenessResult> _readMonthCompleteness({
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

  AnalysisQueryResult<PeriodCompletenessResult> _readWeekCompleteness({
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
}
