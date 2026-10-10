import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_queries.dart';

import 'analysis_test_support.dart';

const _retentionCap = 64;
const _overflowCount = 10;

void _readSearches(AnalysisQueries queries, Iterable<int> range) {
  for (final i in range) {
    queries.readSearch(query: 'q$i');
  }
}

void main() {
  test('readingMoreThanTheCapEvictsTheOldestIdentity', () {
    final h = setupAnalysis();
    final oldest = h.queries.readSearch(query: 'q0');
    _readSearches(h.queries, Iterable.generate(_retentionCap + _overflowCount));

    expect(identical(h.queries.readSearch(query: 'q0'), oldest), isFalse);
    final newest = h.queries.readSearch(query: 'q$_retentionCap');
    expect(
      identical(h.queries.readSearch(query: 'q$_retentionCap'), newest),
      isTrue,
    );
  });

  test('aRecentlyReadIdentitySurvivesWhileTheOldestIsEvicted', () {
    final h = setupAnalysis();
    final first = h.queries.readSearch(query: 'q0');
    final second = h.queries.readSearch(query: 'q1');
    _readSearches(
      h.queries,
      Iterable.generate(_retentionCap - 2, (i) => i + 2),
    );
    h.queries.readSearch(query: 'q0');
    h.queries.readSearch(query: 'extra');

    expect(identical(h.queries.readSearch(query: 'q0'), first), isTrue);
    expect(identical(h.queries.readSearch(query: 'q1'), second), isFalse);
  });

  test('stalePreviousValueSurvivesALedgerChangeWithinTheCap', () async {
    final h = setupAnalysis();
    final window = DateRange(
      DateTime.utc(2027, 5, 1),
      DateTime.utc(2027, 6, 1),
    );
    await settle(h.runner, h.ledger);
    final ready = h.queries.readPeriod(window: window);
    expect(ready.state, AnalysisQueryState.ready);
    _readSearches(h.queries, Iterable.generate(_retentionCap - 1));

    h.ledger.addAccount(
      Account(id: testId(1), name: 'Cash', type: AccountType.checking),
    );
    final stale = h.queries.readPeriod(window: window);

    expect(stale.state, AnalysisQueryState.loading);
    expect(stale.value, same(ready.value));
    expect(stale.sourceRevision, ready.sourceRevision);
  });
}
