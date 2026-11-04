import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_overview.dart';
import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ledger/ledger_session.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/category/category_list_view_model.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

import '../support/phone_shell.dart';
import '../support/ui_test_timeout.dart';

const _pastRetryDelay = Duration(milliseconds: 250);
const _queriesYear = 2026;
const _recentLimit = 4;
const _buildFailure = 'boom';
const _missingLedgerMessage = 'requires a ready ledger';
const _missingQueriesMessage = 'requires ready analysis queries';

final Map<String, ProviderListenable<AsyncValue<Object?>>>
_queryBackedProviders = {
  'Overview': overviewViewModelProvider,
  'Budgets list': budgetsListViewModelProvider,
};

final Map<String, ProviderListenable<AsyncValue<Object?>>> _tabProviders = {
  'Accounts': accountsViewModelProvider,
  'Overview': overviewViewModelProvider,
  'Category list': categoryListViewModelProvider,
  'Plan list': planListViewModelProvider,
  'Recycle bin': recycleBinViewModelProvider,
  'Budgets list': budgetsListViewModelProvider,
  'History': transactionsViewModelProvider(null),
};

class _FailureProbe {
  int failures = 0;

  Never fail() {
    failures += 1;
    throw Exception(_buildFailure);
  }
}

class _FailingLedger extends Ledger {
  _FailingLedger(this._probe);

  final _FailureProbe _probe;

  @override
  LedgerState get state => _probe.fail();

  @override
  List<TransactionCategory> categories(CategoryKind kind) => _probe.fail();
}

class _FailingQueries extends AnalysisQueries {
  _FailingQueries(this._probe)
    : super(
        ledger: Ledger(),
        cache: AnalysisCache(runner: syncComputeRunner),
        today: DateTime.utc(_queriesYear),
      );

  final _FailureProbe _probe;

  @override
  void notifyListeners() {}

  @override
  AnalysisQueryResult<BudgetsOverview> readBudgets({required DateTime month}) =>
      _probe.fail();

  @override
  AnalysisQueryResult<List<EntryRecord>> readRecent({
    int limit = _recentLimit,
    Set<String>? sourceIDs,
  }) => _probe.fail();
}

LedgerSession _failingSession(_FailureProbe probe) => LedgerSession(
  ledger: _FailingLedger(probe),
  analysisCache: AnalysisCache(runner: syncComputeRunner),
);

Future<void> _pumpWithoutLedger(WidgetTester tester, Widget screen) async {
  final app = MaterialApp(home: phoneShell(screen));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ledgerProvider.overrideWithValue(null)],
      child: app,
    ),
  );
  await tester.pump();
}

void main() {
  for (final MapEntry(:key, :value) in _tabProviders.entries) {
    test('$key view model does not retry a failed build', () {
      fakeAsync((async) {
        final probe = _FailureProbe();
        final container = ProviderContainer(
          overrides: [
            ledgerSessionProvider.overrideWithValue(_failingSession(probe)),
            analysisQueriesProvider.overrideWith(
              (ref) => _FailingQueries(probe),
            ),
          ],
        );
        container.listen(value, (previous, next) {}, onError: (_, _) {});

        container.read(value);
        async.flushMicrotasks();
        final failuresBeforeRetryDelay = probe.failures;
        async.elapse(_pastRetryDelay);
        final state = container.read(value);
        container.dispose();

        expect(failuresBeforeRetryDelay, greaterThan(0));
        expect(probe.failures, failuresBeforeRetryDelay);
        expect(state, isA<AsyncError<Object?>>());
        expect(state.isLoading, isFalse);
        expect('${state.error}', contains(_buildFailure));
      });
    });
  }

  for (final MapEntry(:key, :value) in _queryBackedProviders.entries) {
    test('$key view model fails descriptively without analysis queries', () {
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(Ledger()),
          analysisQueriesProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);
      container.listen(value, (previous, next) {}, onError: (_, _) {});

      final state = container.read(value);

      expect('${state.error}', contains(_missingQueriesMessage));
    });
  }

  testWidgets(
    'Accounts screen shows the error when its view model build throws',
    (tester) async {
      await _pumpWithoutLedger(tester, const AccountsScreen());

      expect(find.textContaining(_missingLedgerMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Category list screen shows the error when its view model build throws',
    (tester) async {
      await _pumpWithoutLedger(tester, const CategoryListScreen());

      expect(find.textContaining(_missingLedgerMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}
