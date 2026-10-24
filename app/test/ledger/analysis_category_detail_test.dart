import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/category_detail/category_detail.dart';

const mainID = 'abcdefab-0000-4000-8000-000000000001';
const childID = 'abcdefab-0000-4000-8000-000000000002';
const emptyID = 'abcdefab-0000-4000-8000-000000000003';
const accountID = 'abcdefab-0000-4000-8000-000000000004';
final today = DateTime.utc(2026, 10, 15);

TransactionCategory category(
  String id, {
  String? parent,
  bool included = true,
  CategoryKind kind = CategoryKind.expense,
}) {
  return TransactionCategory(
    id: id,
    name: id,
    kind: kind,
    colorHex: '#123456',
    includeInAnalysis: included,
    parentID: parent,
    symbol: 'tag',
  );
}

LedgerState detailState() {
  final state = LedgerState();
  final account = Account(
    id: accountID,
    name: 'Bank',
    type: AccountType.checking,
  );
  state.addAccount(account);
  state.addCategory(category(mainID));
  state.addCategory(category(childID, parent: mainID));
  state.addCategory(category(emptyID, parent: mainID));
  return state;
}

String book(
  LedgerState state,
  int id,
  String bucket,
  String amount,
  DateTime date, {
  bool included = true,
}) {
  final entry = Entry(
    id: 'abcdefab-0000-4000-8000-${id.toString().padLeft(12, '0')}',
    amount: Decimal.parse(amount),
    name: 'Merchant',
    sourceID: accountID,
    categoryID: bucket,
    date: date,
    includeInAnalysis: included,
  );
  state.addEntry(entry);
  return entry.id;
}

CategoryDetailPeriod period(
  LedgerState state, {
  AnalysisCategoryScope scope = const AllCategoryScope(),
  AnalysisPeriodMode mode = AnalysisPeriodMode.month,
}) {
  return categoryDetailPeriod(
    state: state,
    items: Accounting.analysisItems(state),
    mainID: mainID.toUpperCase(),
    kind: CategoryKind.expense,
    scope: scope,
    period: DateTime(2026, 10, 23, 19),
    mode: mode,
  );
}

void main() {
  test(
    'period keeps full month totals, scoped identities and first record',
    () {
      final state = detailState();
      final older = book(state, 10, childID, '-2.10', DateTime.utc(2024, 2, 1));
      final direct = book(
        state,
        11,
        mainID,
        '-3.20',
        DateTime.utc(2026, 10, 1),
      );
      final child = book(
        state,
        12,
        childID,
        '-7.30',
        DateTime.utc(2026, 10, 31),
      );
      book(state, 13, mainID, '-99', DateTime.utc(2026, 11, 1));

      final result = period(state);
      expect(result.mainCategory?.id, mainID);
      expect(result.window.start, DateTime.utc(2026, 10, 1));
      expect(result.totals.mainTotal, Decimal.parse('10.50'));
      expect(result.totals.childTotals[emptyID], Decimal.zero);
      expect(result.totals.directTotal, Decimal.parse('3.20'));
      expect(result.entryIDs, [child, direct]);
      expect(result.entryIDs, isNot(contains(older)));
      expect(result.firstRecord, DateTime.utc(2024, 2, 1));
      expect(() => result.entryIDs.clear(), throwsUnsupportedError);
      expect(() => result.totals.childTotals.clear(), throwsUnsupportedError);
    },
  );

  test('Sub and Direct keep parent denominator and scope-specific history', () {
    final state = detailState();
    book(state, 20, mainID, '-3', DateTime.utc(2023, 1, 1));
    final direct = book(state, 21, mainID, '-5', DateTime.utc(2026, 10, 1));
    final child = book(state, 22, childID, '-7', DateTime.utc(2026, 10, 2));
    final sub = period(state, scope: SubCategoryScope(childID.toUpperCase()));
    final own = period(state, scope: const DirectCategoryScope());

    expect(sub.totals.mainTotal, Decimal.fromInt(12));
    expect(sub.totals.scopeTotal, Decimal.fromInt(7));
    expect(sub.entryIDs, [child]);
    expect(sub.firstRecord, DateTime.utc(2026, 10, 2));
    expect(own.totals.scopeTotal, Decimal.fromInt(5));
    expect(own.entryIDs, [direct]);
    expect(own.firstRecord, DateTime.utc(2023, 1, 1));
    final empty = period(state, scope: SubCategoryScope(emptyID));
    expect(empty.firstRecord, isNull);
    expect(empty.totals.scopeTotal, Decimal.zero);
  });

  test(
    'entry and category exclusions stay out of totals, bounds and identities',
    () {
      final state = detailState();
      book(state, 30, mainID, '-2', DateTime.utc(2020), included: false);
      book(state, 31, childID, '-3', DateTime.utc(2021));
      book(state, 33, mainID, '-7', DateTime.utc(2026, 10, 1), included: false);
      book(state, 34, childID, '-11', DateTime.utc(2026, 10, 1));
      state.updateCategory(category(childID, parent: mainID, included: false));
      book(state, 32, mainID, '-5', DateTime.utc(2026, 10, 2));
      final result = period(state);
      expect(result.totals.mainTotal, Decimal.fromInt(5));
      expect(result.firstRecord, DateTime.utc(2026, 10, 2));
      expect(result.entryIDs, hasLength(1));
      state.updateCategory(category(mainID, included: false));
      final excludedParent = period(state);
      expect(excludedParent.totals.mainTotal, Decimal.zero);
      expect(excludedParent.firstRecord, isNull);
      expect(excludedParent.entryIDs, isEmpty);
    },
  );

  test('reparented and missing children fall back to All', () {
    final state = detailState();
    book(state, 40, mainID, '-2', DateTime.utc(2026, 10));
    book(state, 41, childID, '-3', DateTime.utc(2026, 10));
    state.updateCategory(category(childID));
    final reparented = period(state, scope: SubCategoryScope(childID));
    final missing = period(state, scope: SubCategoryScope(accountID));
    expect(reparented.scope, const AllCategoryScope());
    expect(reparented.totals.scopeTotal, Decimal.fromInt(2));
    expect(missing.scope, const AllCategoryScope());
    expect(missing.entryIDs, reparented.entryIDs);
  });

  test('year period includes December and excludes next January', () {
    final state = detailState();
    book(state, 50, mainID, '-2', DateTime.utc(2026));
    book(state, 51, childID, '-3', DateTime.utc(2026, 12, 31));
    book(state, 52, mainID, '-7', DateTime.utc(2027));
    final result = period(state, mode: AnalysisPeriodMode.year);
    expect(result.window.start, DateTime.utc(2026));
    expect(result.window.end, DateTime.utc(2027));
    expect(result.totals.mainTotal, Decimal.fromInt(5));
    expect(result.entryIDs, hasLength(2));
  });

  test('spreads use twelve months or three years and selected newest-first entries', () {
    final state = detailState();
    book(state, 60, childID, '-2', DateTime.utc(2024, 1));
    final first = book(state, 61, childID, '-3', DateTime.utc(2026, 10, 20));
    final second = book(state, 62, childID, '-5', DateTime.utc(2026, 10, 20));
    final latest = book(state, 63, childID, '-7', DateTime.utc(2026, 10, 31));
    book(state, 64, mainID, '-11', DateTime.utc(2026, 10, 31));
    final month = spread(state, selected: DateTime(2026, 10, 2, 20));
    expect(month.slots, hasLength(12));
    expect(month.slots.first.period, DateTime.utc(2025, 11));
    expect(month.slots.last.total, Decimal.fromInt(15));
    expect(month.selection?.entryIDs, [latest, second, first]);
    expect(month.selection?.total, Decimal.fromInt(15));
    expect(month.today, today);
    final year = spread(state, mode: AnalysisPeriodMode.year);
    expect(year.slots.map((slot) => slot.period.year), [2024, 2025, 2026]);
    expect(year.slots.map((slot) => slot.total), [
      Decimal.fromInt(2),
      Decimal.zero,
      Decimal.fromInt(15),
    ]);
    expect(year.selection, isNull);
    expect(() => year.slots.clear(), throwsUnsupportedError);
    final empty = spread(state, selected: DateTime.utc(2026, 9));
    expect(empty.selection?.total, Decimal.zero);
    expect(empty.selection?.entryIDs, isEmpty);
  });

  test(
    'kind, unrelated categories and transfers share the inclusion boundary',
    () {
      final state = detailState();
      const incomeID = 'abcdefab-0000-4000-8000-000000000005';
      const otherID = 'abcdefab-0000-4000-8000-000000000006';
      const savingsID = 'abcdefab-0000-4000-8000-000000000007';
      state.addCategory(category(incomeID, kind: CategoryKind.income));
      state.addCategory(category(otherID));
      final savings = Account(
        id: savingsID,
        name: 'Savings',
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      );
      state.addAccount(savings);
      final expense = book(state, 70, childID, '-2', DateTime.utc(2026, 10));
      final income = book(state, 71, incomeID, '3', DateTime.utc(2026, 10));
      book(state, 72, otherID, '-5', DateTime.utc(2020));
      book(state, 73, otherID, '-7', DateTime.utc(2026, 10));
      final transfer = Entry(
        id: null,
        name: 'Transfer',
        sourceID: accountID,
        destinationID: savingsID,
        amount: Decimal.fromInt(11),
        date: DateTime.utc(2026, 10),
      );
      state.addEntry(transfer);
      final expenses = period(state);
      expect(expenses.totals.scopeTotal, Decimal.fromInt(2));
      expect(expenses.entryIDs, [expense]);
      expect(expenses.firstRecord, DateTime.utc(2026, 10));
      final incomes = categoryDetailPeriod(
        state: state,
        items: Accounting.analysisItems(state),
        mainID: incomeID,
        kind: CategoryKind.income,
        scope: const AllCategoryScope(),
        period: today,
        mode: AnalysisPeriodMode.month,
      );
      expect(incomes.totals.scopeTotal, Decimal.fromInt(3));
      expect(incomes.entryIDs, [income]);
    },
  );

  test('future month spreads include saved scoped selections', () {
    final state = detailState();
    final first = book(state, 80, childID, '-3', DateTime.utc(2026, 12, 5));
    final latest = book(state, 81, childID, '-7', DateTime.utc(2026, 12, 20));
    final future = categoryDetailSpread(
      state: state,
      items: Accounting.analysisItems(state),
      mainID: mainID,
      kind: CategoryKind.expense,
      scope: SubCategoryScope(childID),
      endPeriod: DateTime.utc(2026, 12, 31),
      mode: AnalysisPeriodMode.month,
      selectedPeriod: DateTime.utc(2026, 12, 1),
      today: today,
    );

    expect(future.slots, hasLength(12));
    expect(future.slots.map((slot) => slot.period), [
      for (var month = 1; month <= 12; month++) DateTime.utc(2026, month),
    ]);
    expect(future.slots.last.total, Decimal.fromInt(10));
    expect(future.selection?.total, Decimal.fromInt(10));
    expect(future.selection?.entryIDs, [latest, first]);

    final emptyScope = categoryDetailSpread(
      state: state,
      items: Accounting.analysisItems(state),
      mainID: mainID,
      kind: CategoryKind.expense,
      scope: SubCategoryScope(emptyID),
      endPeriod: DateTime.utc(2027, 12),
      mode: AnalysisPeriodMode.month,
      selectedPeriod: DateTime.utc(2027, 11),
      today: today,
    );
    expect(emptyScope.slots, hasLength(12));
    expect(emptyScope.selection?.total, Decimal.zero);
    expect(emptyScope.selection?.entryIDs, isEmpty);

    final missingMain = categoryDetailSpread(
      state: state,
      items: const [],
      mainID: accountID,
      kind: CategoryKind.expense,
      scope: const AllCategoryScope(),
      endPeriod: DateTime.utc(2027, 12),
      mode: AnalysisPeriodMode.month,
      selectedPeriod: DateTime.utc(2027, 12),
      today: today,
    );
    expect(missingMain.slots, hasLength(12));
    expect(missingMain.selection?.total, Decimal.zero);
    expect(missingMain.selection?.entryIDs, isEmpty);
  });

  test(
    'future year spread ends fail while missing main gives empty metadata',
    () {
      final state = detailState();
      CategoryDetailSpread futureSpread() => categoryDetailSpread(
        state: state,
        items: const [],
        mainID: mainID,
        kind: CategoryKind.expense,
        scope: const AllCategoryScope(),
        endPeriod: DateTime.utc(2027),
        mode: AnalysisPeriodMode.year,
        selectedPeriod: null,
        today: today,
      );
      expect(futureSpread, throwsArgumentError);
      final result = categoryDetailPeriod(
        state: state,
        items: const [],
        mainID: accountID,
        kind: CategoryKind.expense,
        scope: const AllCategoryScope(),
        period: today,
        mode: AnalysisPeriodMode.month,
      );
      expect(result.mainCategory, isNull);
      expect(result.children, isEmpty);
      expect(result.totals.mainTotal, Decimal.zero);
    },
  );
}

CategoryDetailSpread spread(
  LedgerState state, {
  AnalysisPeriodMode mode = AnalysisPeriodMode.month,
  DateTime? selected,
}) {
  return categoryDetailSpread(
    state: state,
    items: Accounting.analysisItems(state),
    mainID: mainID,
    kind: CategoryKind.expense,
    scope: SubCategoryScope(childID),
    endPeriod: today,
    mode: mode,
    selectedPeriod: selected,
    today: today,
  );
}
