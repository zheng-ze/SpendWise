import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/category_detail/category_detail.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_intent.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

const _mainID = 'abcdefab-0000-4000-8000-000000000001';
const _firstID = 'abcdefab-0000-4000-8000-000000000002';
const _secondID = 'abcdefab-0000-4000-8000-000000000003';
const _thirdID = 'abcdefab-0000-4000-8000-000000000004';
const _accountID = 'abcdefab-0000-4000-8000-000000000005';
const _revision = 7;

void main() {
  test('breakdown shares use parent totals and equal children rank by name then ID', () {
    final state = _state();
    state.addCategory(_category(_firstID, 'Zulu', parent: _mainID));
    state.addCategory(_category(_thirdID, 'Alpha', parent: _mainID));
    state.addCategory(_category(_secondID, 'Alpha', parent: _mainID));
    _book(state, _firstID, '-10');
    _book(state, _secondID, '-10');
    _book(state, _thirdID, '-10');
    _book(state, _mainID, '-20');

    final body = _project(state).body as CategoryDetailReadyBody;

    expect(body.children.map((child) => child.id), [
      _secondID,
      _thirdID,
      _firstID,
    ]);
    expect(body.breakdown.map((row) => row.id), [
      _mainID,
      _secondID,
      _thirdID,
      _firstID,
    ]);
    expect(body.breakdown.map((row) => row.shareLabel), [
      '40.0% of Food',
      '20.0% of Food',
      '20.0% of Food',
      '20.0% of Food',
    ]);
    expect(body.chips.map((chip) => chip.label), [
      'All Food',
      'Alpha',
      'Alpha',
      'Zulu',
      'Direct to Food',
    ]);
    expect(() => body.chips.clear(), throwsUnsupportedError);
    expect(() => body.breakdown.clear(), throwsUnsupportedError);
  });

  test('zero children remain reachable and zero Direct is a chip without a breakdown row', () {
    final state = _state();
    state.addCategory(_category(_firstID, 'Empty', parent: _mainID));

    final body = _project(state).body as CategoryDetailReadyBody;

    expect(body.showSubcategories, isTrue);
    expect(body.breakdown.single.id, _firstID);
    expect(body.breakdown.single.total, Decimal.zero);
    expect(body.breakdown.single.shareLabel, '0.0% of Food');
    expect(body.chips.last.scope, const DirectScope());
    final childScope = body.chips[1].scope;
    expect(childScope, isA<SubScope>());
    expect((childScope as SubScope).subID, _firstID);
  });

  test('childless detail exposes no scope controls or Subcategories', () {
    final body = _project(_state()).body as CategoryDetailReadyBody;

    expect(body.chips, isEmpty);
    expect(body.showSubcategories, isFalse);
  });

  test(
    'removed child scope falls back to All before publishing financial content',
    () {
      final state = _state();
      final direct = _book(state, _mainID, '-9');

      final projected = _project(state, scope: SubScope(_firstID));
      final body = projected.body as CategoryDetailReadyBody;

      expect(projected.scope, const AllScope());
      expect(body.totals.scopeTotal, Decimal.fromInt(9));
      expect(body.sections.single.rows.single.id, direct.id);
    },
  );

  test(
    'year detail normalizes its incoming period and retains income semantics',
    () {
      final state = _state(kind: CategoryKind.income);
      final income = _book(state, _mainID, '25');
      final projected = _project(state, kind: CategoryKind.income, year: true);
      final body = projected.body as CategoryDetailReadyBody;
      final row = body.sections.single.rows.single;

      expect(projected.detailDate, DateTime.utc(2026));
      expect(projected.subtitle, '2026');
      expect(projected.kind, CategoryKind.income);
      expect(body.amountKind, AmountKind.income);
      expect(body.totals.scopeTotal, Decimal.fromInt(25));
      expect(row.id, income.id);
      expect(row.amountKind, AmountKind.income);
      expect(formatSignedMoney(row.amount), '+S\$25.00');
      expect(row.title, 'Merchant');
      expect(row.note, isEmpty);
      expect(row.accountLine, 'Direct to Food / Checking');
    },
  );

  test('selected empty trend period keeps zero total and empty rows', () {
    final state = _state();
    final args = _args();
    final today = DateTime.utc(2026, 10, 23);
    final currentMonth = monthSerial(today);
    final context = TrendsContext(
      currentMonth: currentMonth,
      bounds: TrendsBounds.fromFirstRecord(null, currentMonth),
    );
    final intent = CategoryDetailIntent.initial(args).selectSlot(11, context);
    final basis = intent.trend.effective(context);
    final items = Accounting.analysisItems(state);
    final period = categoryDetailPeriod(
      state: state,
      items: items,
      mainID: _mainID,
      kind: CategoryKind.expense,
      scope: categoryDetailAnalysisScope(intent.scope),
      period: args.initialDate,
      mode: AnalysisPeriodMode.month,
    );
    final spread = categoryDetailSpread(
      state: state,
      items: items,
      mainID: _mainID,
      kind: CategoryKind.expense,
      scope: categoryDetailAnalysisScope(intent.scope),
      endPeriod: monthStartOf(basis.end),
      mode: AnalysisPeriodMode.month,
      selectedPeriod: monthStartOf(basis.selected),
      today: today,
    );
    final projected = projectCategoryDetailWithTrend(
      periodResult: AnalysisQueryResult(
        value: period,
        state: AnalysisQueryState.ready,
        sourceRevision: _revision,
      ),
      spreadResult: AnalysisQueryResult(
        value: spread,
        state: AnalysisQueryState.ready,
        sourceRevision: _revision,
      ),
      ledgerRevision: _revision,
      ledgerState: state,
      args: args,
      intent: intent,
      trendContext: context,
      basis: basis,
      today: today,
    );
    final body = projected.body as CategoryDetailReadyBody;
    final selection = body.trend!.selection!;

    expect(body.trend!.bars[body.trend!.selectedIndex].value, 0);
    expect(selection.headline.amount, '-S\$0.00');
    expect(selection.rows, isEmpty);
  });

  test('missing main uses Uncategorized and retains matching entries', () {
    final fixture = _state();
    fixture.addCategory(_category(_firstID, 'Child', parent: _mainID));
    final entry = _book(fixture, _firstID, '-3');
    final state = LedgerState(
      moneySources: fixture.moneySources,
      entries: fixture.entries,
      categories: {
        for (final category in fixture.categories.entries)
          if (category.key != _mainID) category.key: category.value,
      },
    );

    final body = _project(state).body as CategoryDetailReadyBody;

    expect(body.title, 'Uncategorized');
    expect(body.sections.single.rows.single.id, entry.id);
    expect(body.amountKind, AmountKind.expense);
    expect(formatSignedMoney(-body.totals.scopeTotal), '-S\$3.00');
  });

  test('pending and failed retained values and stale revisions never become ready content', () {
    final state = _state();
    _book(state, _mainID, '-10');
    final period = _period(state);
    const scope = DirectScope();
    final loading = _projectResult(
      state,
      period,
      AnalysisQueryState.loading,
      scope: scope,
    );
    final failed = _projectResult(
      state,
      period,
      AnalysisQueryState.failed,
      scope: scope,
    );
    final stale = _projectResult(
      state,
      period,
      AnalysisQueryState.ready,
      revision: _revision - 1,
    );
    final absent = _projectResult(state, null, AnalysisQueryState.ready);

    expect(loading.body, isA<CategoryDetailLoadingBody>());
    expect(loading.scope, scope);
    expect(failed.body, isA<CategoryDetailErrorBody>());
    expect(failed.scope, scope);
    expect(stale.body, isA<CategoryDetailLoadingBody>());
    expect(absent.body, isA<CategoryDetailLoadingBody>());
  });
}

TransactionCategory _category(
  String id,
  String name, {
  String? parent,
  CategoryKind kind = CategoryKind.expense,
}) {
  return TransactionCategory(
    id: id,
    name: name,
    kind: kind,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: parent,
    symbol: 'restaurant',
  );
}

LedgerState _state({CategoryKind kind = CategoryKind.expense}) {
  final state = LedgerState();
  final account = Account(
    id: _accountID,
    name: 'Checking',
    type: AccountType.checking,
  );
  state.addAccount(account);
  state.addCategory(_category(_mainID, 'Food', kind: kind));
  return state;
}

Entry _book(LedgerState state, String categoryID, String amount) {
  final entry = Entry(
    amount: Decimal.parse(amount),
    name: 'Merchant',
    sourceID: _accountID,
    categoryID: categoryID,
    date: DateTime.utc(2026, 10, 31),
  );
  state.addEntry(entry);
  return entry;
}

CategoryDetailArgs _args({
  CategoryKind kind = CategoryKind.expense,
  bool year = false,
}) {
  return CategoryDetailArgs(
    mainID: _mainID,
    kind: kind,
    isYearRange: year,
    initialDate: DateTime(2026, 10, 23, 17),
  );
}

CategoryDetailPeriod _period(
  LedgerState state, {
  CategoryScope scope = const AllScope(),
  CategoryKind kind = CategoryKind.expense,
  bool year = false,
}) {
  return categoryDetailPeriod(
    state: state,
    items: Accounting.analysisItems(state),
    mainID: _mainID,
    kind: kind,
    scope: categoryDetailAnalysisScope(scope),
    period: _args().initialDate,
    mode: year ? AnalysisPeriodMode.year : AnalysisPeriodMode.month,
  );
}

CategoryDetailViewState _project(
  LedgerState state, {
  CategoryScope scope = const AllScope(),
  CategoryKind kind = CategoryKind.expense,
  bool year = false,
}) {
  final period = _period(state, scope: scope, kind: kind, year: year);
  final result = AnalysisQueryResult<CategoryDetailPeriod>(
    value: period,
    state: AnalysisQueryState.ready,
    sourceRevision: _revision,
  );
  return projectCategoryDetail(
    result: result,
    ledgerRevision: _revision,
    ledgerState: state,
    args: _args(kind: kind, year: year),
    scope: scope,
  );
}

CategoryDetailViewState _projectResult(
  LedgerState state,
  CategoryDetailPeriod? period,
  AnalysisQueryState queryState, {
  int revision = _revision,
  CategoryScope scope = const AllScope(),
}) {
  final result = AnalysisQueryResult<CategoryDetailPeriod>(
    value: period,
    state: queryState,
    sourceRevision: revision,
  );
  return projectCategoryDetail(
    result: result,
    ledgerRevision: _revision,
    ledgerState: state,
    args: _args(),
    scope: scope,
  );
}
