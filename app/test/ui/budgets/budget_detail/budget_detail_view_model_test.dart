import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';

import 'budget_detail_test_support.dart';

void main() {
  final october = DateTime.utc(2026, 10, 28);
  final september = DateTime.utc(2026, 9);

  Entry lunch(DateTime date, {String amount = '-10'}) => Entry(
    amount: dec(amount),
    name: 'Lunch',
    sourceID: checkingAccount.id,
    date: date,
  );

  List<LimitEvent> limitsWithRaise() => [
    LimitEvent(
      effectiveFromMonth: null,
      value: dec('100'),
      kind: LimitEventKind.defaultLimit,
    ),
    LimitEvent(
      effectiveFromMonth: const YearMonth(2026, 11),
      value: dec('200'),
      kind: LimitEventKind.defaultLimit,
    ),
  ];

  void expectRowsCoherent(BudgetDetailViewState state) {
    final dayTotals = <DateTime, Decimal>{};
    for (final row in state.countedEntries) {
      expect(state.ledgerState.entries.containsKey(row.entry.id), isTrue);
      final day = startOfDayUtc(row.entry.date);
      dayTotals[day] = (dayTotals[day] ?? Decimal.zero) + row.amount;
    }
    final dayTotalSum = dayTotals.values.fold(
      Decimal.zero,
      (sum, total) => sum + total,
    );
    expect(dayTotalSum, state.spent);
  }

  test('opens on the effective month for the displayed year', () async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);

    final context = detailContext(container);

    expect(context.displayedYear, DateTime.utc(2026));
    expect(context.selectedMonth, DateTime.utc(2026, 10));
  });

  test('selectMonth and changeYear update the context owner', () async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);
    final viewModel = container.read(
      budgetDetailViewModelProvider(detailBudgetID).notifier,
    );

    viewModel.selectMonth(september);
    expect(detailContext(container).selectedMonth, september);
    expect(detailContext(container).displayedYear, DateTime.utc(2026));

    viewModel.changeYear(DateTime.utc(2027));
    expect(detailContext(container).displayedYear, DateTime.utc(2027));
    expect(detailContext(container).selectedMonth, DateTime.utc(2027, 9));
  });

  test(
    'a ledger commit leaves the selected month and year unchanged',
    () async {
      final container = detailContainer(
        ledger: detailLedger(budgets: [detailBudget()]),
        clock: DetailClock(october),
      );
      keepDetailAlive(container);
      await settledDetail(container);
      container
          .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
          .selectMonth(september);

      container.read(ledgerProvider)!.addEntry(lunch(DateTime.utc(2026, 9, 3)));
      final state = await settledDetail(container);

      expect(state.selectedMonth, september);
      expect(state.displayedYear, DateTime.utc(2026));
    },
  );

  test('an AnalysisQueries notification leaves the selected month and year unchanged', () async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);
    await settledDetail(container);
    container
        .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
        .selectMonth(september);

    container
        .read(analysisQueriesProvider)!
        .setToday(DateTime.utc(2026, 10, 29));
    final state = await settledDetail(container);

    expect(state.selectedMonth, september);
    expect(state.displayedYear, DateTime.utc(2026));
  });

  test('an effective-month change leaves the selected month and year '
      'unchanged', () async {
    final clock = DetailClock(october);
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: clock,
    );
    keepDetailAlive(container);
    await settledDetail(container);
    container
        .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
        .selectMonth(september);

    clock.now = DateTime.utc(2026, 11, 2);
    container.invalidate(todayProvider);
    final state = await settledDetail(container);

    expect(state.selectedMonth, september);
    expect(state.displayedYear, DateTime.utc(2026));
  });

  test('a ready state headline equals the folded counted rows and the '
      'projection summary', () async {
    final topUp = Entry(
      amount: dec('40'),
      name: 'Top up',
      sourceID: checkingAccount.id,
      destinationID: savingsAccount.id,
      date: DateTime.utc(2026, 10, 1),
    );
    final container = detailContainer(
      ledger: detailLedger(
        budgets: [detailBudget()],
        entries: [lunch(DateTime.utc(2026, 10, 1)), topUp],
      ),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);

    final state = await settledDetail(container);

    expect(state.phase, BudgetDetailPhase.ready);
    expect(state.countedEntries, hasLength(2));
    expect(state.spent, dec('50'));
    expect(state.projection?.projection.summary?.spent, state.spent);
    expect(state.projection?.selectedLimit, dec('100'));
  });

  test('deleting a counted entry while a refresh is pending removes its row '
      'and its amount from the live totals', () async {
    final second = lunch(DateTime.utc(2026, 10, 2), amount: '-25');
    final container = detailContainer(
      ledger: detailLedger(
        budgets: [detailBudget()],
        entries: [lunch(DateTime.utc(2026, 10, 1)), second],
      ),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);
    await settledDetail(container);

    container.read(ledgerProvider)!.deleteEntry(second.id);
    final pending = detailState(container);

    expect(pending.phase, BudgetDetailPhase.loading);
    expect(pending.countedEntries, hasLength(1));
    expect(pending.spent, dec('10'));
    expect(pending.projection, isNotNull);
    expectRowsCoherent(pending);
  });

  test('deleting a counted entry while the refresh has failed removes its row '
      'and keeps the projection retained', () async {
    var calls = 0;
    Future<List<AnalysisItem>> failingRefresh(LedgerState state) async {
      calls += 1;
      if (calls > 1) throw StateError('refresh unavailable');
      return Accounting.analysisItems(state);
    }

    final second = lunch(DateTime.utc(2026, 10, 2), amount: '-25');
    final container = detailContainer(
      ledger: detailLedger(
        budgets: [detailBudget()],
        entries: [lunch(DateTime.utc(2026, 10, 1)), second],
      ),
      clock: DetailClock(october),
      runner: failingRefresh,
    );
    keepDetailAlive(container);
    await settledDetail(container);

    container.read(ledgerProvider)!.deleteEntry(second.id);
    final failed = await settledDetail(container);

    expect(failed.phase, BudgetDetailPhase.failed);
    expect('${failed.error}', contains('refresh unavailable'));
    expect(failed.countedEntries, hasLength(1));
    expect(failed.spent, dec('10'));
    expect(failed.projection, isNotNull);
    expectRowsCoherent(failed);
  });

  test('a category rename during a pending refresh updates the live title '
      'and category label', () async {
    final container = detailContainer(
      ledger: detailLedger(
        budgets: [detailBudget(categoryID: foodCategory.id)],
      ),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);
    await settledDetail(container);

    container
        .read(ledgerProvider)!
        .updateCategory(
          TransactionCategory(
            id: foodCategory.id,
            name: 'Groceries',
            kind: CategoryKind.expense,
            colorHex: '#00AA00',
            includeInAnalysis: true,
            parentID: null,
            symbol: 'restaurant',
          ),
        );
    final pending = detailState(container);

    expect(pending.phase, BudgetDetailPhase.loading);
    expect(pending.title, 'Groceries');
    expect(pending.categoryName, 'Groceries');
    expect(pending.projection, isNotNull);
  });

  test('whole-budget freshness follows the live ledger while a refresh is '
      'pending', () async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);
    await settledDetail(container);
    expect(detailState(container).hasCountedEntries, isFalse);

    final added = lunch(DateTime.utc(2026, 10, 2));
    container.read(ledgerProvider)!.addEntry(added);
    final pending = detailState(container);

    expect(pending.phase, BudgetDetailPhase.loading);
    expect(pending.hasCountedEntries, isTrue);
    expect(pending.countedEntries, hasLength(1));
  });

  test(
    'a retained projection does not apply to a different selected month',
    () async {
      final container = detailContainer(
        ledger: detailLedger(budgets: [detailBudget()]),
        clock: DetailClock(october),
      );
      keepDetailAlive(container);
      await settledDetail(container);

      container
          .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
          .selectMonth(september);
      final pending = detailState(container);

      expect(pending.projection?.selectedMonth, isNot(october));
    },
  );

  test('an initial compute failure reports the actual reason and retry '
      'restores the detail', () async {
    var calls = 0;
    Future<List<AnalysisItem>> flakyRunner(LedgerState state) async {
      calls += 1;
      if (calls == 1) throw StateError('compute unavailable');
      return Accounting.analysisItems(state);
    }

    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
      runner: flakyRunner,
    );
    keepDetailAlive(container);
    final failed = await settledDetail(container);

    expect(failed.phase, BudgetDetailPhase.failed);
    expect('${failed.error}', contains('compute unavailable'));
    expect(failed.projection, isNull);

    container
        .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
        .retry();
    final restored = await settledDetail(container);

    expect(restored.phase, BudgetDetailPhase.ready);
    expect(restored.error, isNull);
    expect(detailContext(container).selectedMonth, DateTime.utc(2026, 10));
  });

  test('an unresolvable limit reports the thrown reason from the pure '
      'projection', () async {
    final futureOnly = detailBudget(
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: const YearMonth(2027, 1),
          value: dec('100'),
          kind: LimitEventKind.defaultLimit,
        ),
      ],
    );
    final container = detailContainer(
      ledger: detailLedger(budgets: [futureOnly]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);

    final state = await settledDetail(container);

    expect(state.phase, BudgetDetailPhase.failed);
    expect('${state.error}', contains('no default limit event'));
    expect(state.projection, isNull);
  });

  test('the current-limit scalar stays at today limit across displayed years '
      'and selected months', () async {
    final container = detailContainer(
      ledger: detailLedger(
        budgets: [detailBudget(limitEvents: limitsWithRaise())],
      ),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);
    await settledDetail(container);
    final viewModel = container.read(
      budgetDetailViewModelProvider(detailBudgetID).notifier,
    );

    viewModel.selectMonth(DateTime.utc(2026, 12));
    final december = (await settledDetail(container)).projection!;
    viewModel.changeYear(DateTime.utc(2027));
    final nextYear = (await settledDetail(container)).projection!;

    expect(december.currentLimit, dec('100'));
    expect(december.selectedLimit, dec('200'));
    expect(nextYear.currentLimit, dec('100'));
    expect(detailContext(container).selectedMonth, DateTime.utc(2027, 12));
  });

  test(
    'calendar rollover moves the current-limit scalar to the new month',
    () async {
      final clock = DetailClock(october);
      final container = detailContainer(
        ledger: detailLedger(
          budgets: [detailBudget(limitEvents: limitsWithRaise())],
        ),
        clock: clock,
      );
      keepDetailAlive(container);
      expect(
        (await settledDetail(container)).projection?.currentLimit,
        dec('100'),
      );

      clock.now = DateTime.utc(2026, 11, 1);
      container.invalidate(todayProvider);

      expect(
        (await settledDetail(container)).projection?.currentLimit,
        dec('200'),
      );
    },
  );

  test('the chart scale includes the current-limit scalar', () async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);

    final state = await settledDetail(container);

    expect(state.projection?.chartMaxYValue, closeTo(115.0, 1e-9));
  });

  test(
    'requestLimitEdit emits BudgetLimitEditRequested, clearStep resets it',
    () async {
      final container = detailContainer(
        ledger: detailLedger(budgets: [detailBudget()]),
        clock: DetailClock(october),
      );
      keepDetailAlive(container);
      await settledDetail(container);
      final viewModel = container.read(
        budgetDetailViewModelProvider(detailBudgetID).notifier,
      );

      viewModel.requestLimitEdit();
      expect(detailState(container).step, isA<BudgetLimitEditRequested>());

      viewModel.clearStep();
      expect(detailState(container).step, isNull);
    },
  );

  test('a deleted budget reports the deleted phase', () async {
    final container = detailContainer(
      ledger: detailLedger(),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);

    expect(detailState(container).phase, BudgetDetailPhase.deleted);
    expect(detailState(container).projection, isNull);
  });

  test('chartMaxY extends 15 percent past the largest bar, floors at 1.0', () {
    expect(chartMaxY([dec('0')], [dec('0')]), 1.0);
    expect(chartMaxY([dec('100')], [dec('50')]), closeTo(115.0, 1e-9));
    expect(chartMaxY([dec('50')], [dec('200')]), closeTo(230.0, 1e-9));
  });

  test(
    'the analysis query returns a ready coherent result after settling',
    () async {
      final container = detailContainer(
        ledger: detailLedger(budgets: [detailBudget()]),
        clock: DetailClock(october),
      );
      keepDetailAlive(container);
      final queries = container.read(analysisQueriesProvider)!;
      await settledDetail(container);

      final result = queries.readBudgetDetail(
        budgetID: detailBudgetID,
        displayedYear: DateTime.utc(2026),
        selectedMonth: october,
      );

      expect(result.state, AnalysisQueryState.ready);
      expect(result.sourceRevision, container.read(ledgerProvider)!.revision);
    },
  );
}
