import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_presentation.dart';
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
          .changeYear(DateTime.utc(2027));
      container
          .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
          .selectMonth(DateTime.utc(2027, 9));

      container.read(ledgerProvider)!.addEntry(lunch(DateTime.utc(2026, 9, 3)));
      final state = await settledDetail(container);

      expect(state.selectedMonth, DateTime.utc(2027, 9));
      expect(state.displayedYear, DateTime.utc(2027));
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
        .changeYear(DateTime.utc(2027));
    container
        .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
        .selectMonth(DateTime.utc(2027, 9));

    container
        .read(analysisQueriesProvider)!
        .setToday(DateTime.utc(2026, 10, 29));
    final state = await settledDetail(container);

    expect(state.selectedMonth, DateTime.utc(2027, 9));
    expect(state.displayedYear, DateTime.utc(2027));
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
    expect(state.projection?.limit, dec('100'));
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

  test(
    'counted entries follow the live ledger while a refresh is pending',
    () async {
      final container = detailContainer(
        ledger: detailLedger(budgets: [detailBudget()]),
        clock: DetailClock(october),
      );
      keepDetailAlive(container);
      await settledDetail(container);
      expect(detailState(container).countedEntries, isEmpty);

      final added = lunch(DateTime.utc(2026, 10, 2));
      container.read(ledgerProvider)!.addEntry(added);
      final pending = detailState(container);

      expect(pending.phase, BudgetDetailPhase.loading);
      expect(pending.countedEntries, hasLength(1));
    },
  );

  Future<ProviderContainer> gatedDetailContainer(
    GatedComputeRunner runner,
    DetailClock clock,
  ) async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: clock,
      runner: runner.call,
    );
    addTearDown(runner.release);
    keepDetailAlive(container);
    await settledDetail(container);
    runner.hold();
    return container;
  }

  void commitWhilePending(ProviderContainer container) {
    container.read(ledgerProvider)!.addEntry(lunch(DateTime.utc(2026, 10, 3)));
  }

  test('a pending refresh keeps the projection for the same ledger, year and '
      'month', () async {
    final container = await gatedDetailContainer(
      GatedComputeRunner(),
      DetailClock(october),
    );
    commitWhilePending(container);

    final pending = detailState(container);

    expect(pending.phase, BudgetDetailPhase.loading);
    expect(pending.projection?.selectedMonth, DateTime.utc(2026, 10));
  });

  test(
    'a pending selected-month change drops the retained projection',
    () async {
      final container = await gatedDetailContainer(
        GatedComputeRunner(),
        DetailClock(october),
      );
      commitWhilePending(container);
      container
          .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
          .selectMonth(september);

      final pending = detailState(container);

      expect(pending.phase, BudgetDetailPhase.loading);
      expect(pending.projection, isNull);
      expect(budgetDetailPresentation(pending).body, BudgetDetailBody.skeleton);
    },
  );

  test(
    'a pending displayed-year change drops the retained projection',
    () async {
      final container = await gatedDetailContainer(
        GatedComputeRunner(),
        DetailClock(october),
      );
      commitWhilePending(container);
      container
          .read(budgetDetailViewModelProvider(detailBudgetID).notifier)
          .changeYear(DateTime.utc(2027));

      final pending = detailState(container);

      expect(pending.phase, BudgetDetailPhase.loading);
      expect(pending.projection, isNull);
      expect(budgetDetailPresentation(pending).body, BudgetDetailBody.skeleton);
    },
  );

  test('a pending read in another displayed year does not reuse the retained '
      'projection for a matching selected month', () async {
    final container = await gatedDetailContainer(
      GatedComputeRunner(),
      DetailClock(october),
    );
    commitWhilePending(container);
    final viewModel = container.read(
      budgetDetailViewModelProvider(detailBudgetID).notifier,
    );
    viewModel.changeYear(DateTime.utc(2027));
    viewModel.selectMonth(DateTime.utc(2026, 10));

    final pending = detailState(container);

    expect(pending.selectedMonth, DateTime.utc(2026, 10));
    expect(pending.displayedYear, DateTime.utc(2027));
    expect(pending.projection, isNull);
  });

  test('a ledger swap with a pending refresh drops the projection of the old '
      'ledger', () async {
    final clock = DetailClock(october);
    final runner = GatedComputeRunner();
    final container = await gatedDetailContainer(runner, clock);

    container.updateOverrides([
      ledgerProvider.overrideWithValue(detailLedger(budgets: [detailBudget()])),
      clockProvider.overrideWithValue(clock.read),
      analysisComputeRunnerProvider.overrideWithValue(runner.call),
    ]);
    final pending = detailState(container);

    expect(pending.phase, BudgetDetailPhase.loading);
    expect(pending.projection, isNull);
  });

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
    final contextOwner = container.read(
      budgetDetailContextProvider(detailBudgetID).notifier,
    );
    contextOwner.changeYear(DateTime.utc(2027));
    contextOwner.selectMonth(DateTime.utc(2027, 9));
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
    expect(restored.selectedMonth, DateTime.utc(2027, 9));
    expect(restored.displayedYear, DateTime.utc(2027));
  });

  test('the projection carries the single budget limit across displayed '
      'years and selected months', () async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget(limit: dec('150'))]),
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

    expect(december.limit, dec('150'));
    expect(nextYear.limit, dec('150'));
  });

  test('the chart scale includes the limit', () async {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);

    final state = await settledDetail(container);

    expect(state.projection?.chartMaxYValue, closeTo(115.0, 1e-9));
  });

  BudgetDetailViewModel keepViewModel(ProviderContainer container) {
    keepDetailAlive(container);
    return container.read(
      budgetDetailViewModelProvider(detailBudgetID).notifier,
    );
  }

  ProviderContainer limitContainer({bool withBudget = true}) => detailContainer(
    ledger: detailLedger(budgets: withBudget ? [detailBudget()] : []),
    clock: DetailClock(october),
  );

  test('requestEdit emits only when the budget exists', () async {
    final present = limitContainer();
    keepViewModel(present).requestEdit();
    final missing = limitContainer(withBudget: false);
    keepViewModel(missing).requestEdit();

    expect(detailState(present).step, isA<BudgetEditRequested>());
    expect(detailState(missing).step, isNull);
  });

  test('deleteBudget deletes the budget once and leaves entries', () {
    final entry = lunch(DateTime.utc(2026, 10, 3));
    final other = detailBudget(id: 'b2', categoryID: foodCategory.id);
    final ledger = detailLedger(
      budgets: [detailBudget(), other],
      entries: [entry],
    );
    final container = detailContainer(
      ledger: ledger,
      clock: DetailClock(october),
    );

    final revision = ledger.revision;

    keepViewModel(container).deleteBudget();

    expect(ledger.revision, revision + 1);
    expect(ledger.state.budgets.keys, [other.id]);
    expect(ledger.state.entries.containsKey(entry.id), isTrue);
  });

  test('deleteBudget does nothing when the budget is missing', () {
    final ledger = detailLedger(budgets: [detailBudget(id: 'b2')]);
    final container = detailContainer(
      ledger: ledger,
      clock: DetailClock(october),
    );
    final viewModel = keepViewModel(container);
    final revision = ledger.revision;

    viewModel.deleteBudget();

    expect(ledger.revision, revision);
    expect(ledger.state.budgets.keys, ['b2']);
  });

  test('clearStep resets the edit step', () async {
    final container = limitContainer();
    final viewModel = keepViewModel(container);
    viewModel.requestEdit();

    viewModel.clearStep();

    expect(detailState(container).step, isNull);
  });

  test('liveLimit follows the ledger and is null for a missing budget', () {
    final container = limitContainer();
    final viewModel = keepViewModel(container);
    final missing = keepViewModel(limitContainer(withBudget: false));

    expect(viewModel.liveLimit, dec('100'));
    container.read(ledgerProvider)!.updateBudgetLimit(detailBudgetID, dec('7'));
    expect(viewModel.liveLimit, dec('7'));
    expect(missing.liveLimit, isNull);
  });

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
  test('old analysis completing after session replacement cannot publish into the new owner', () async {
    final oldWork = Completer<List<AnalysisItem>>();
    var hold = false;
    Future<List<AnalysisItem>> runner(LedgerState state) {
      if (hold) return oldWork.future;
      return syncComputeRunner(state);
    }

    final clock = DetailClock(october);
    final oldLedger = detailLedger(budgets: [detailBudget()]);
    final container = detailContainer(
      ledger: oldLedger,
      clock: clock,
      runner: runner,
    );
    keepDetailAlive(container);
    await settledDetail(container);
    hold = true;
    oldLedger.addEntry(lunch(october));
    await pumpEventQueue();
    hold = false;
    final replacement = detailLedger(budgets: [detailBudget()]);
    container.updateOverrides([
      ledgerProvider.overrideWithValue(replacement),
      clockProvider.overrideWithValue(clock.read),
      analysisComputeRunnerProvider.overrideWithValue(runner),
    ]);
    final before = await settledDetail(container);
    oldWork.complete(Accounting.analysisItems(oldLedger.state));
    final after = await settledDetail(container);
    expect(identical(after.ledger, replacement), isTrue);
    expect(after.spent, Decimal.zero);
    expect(after.projection, same(before.projection));
  });

  test(
    'old analysis completing after disposal cannot publish into a new owner',
    () async {
      final oldWork = Completer<List<AnalysisItem>>();
      var hold = false;
      Future<List<AnalysisItem>> runner(LedgerState state) {
        if (hold) return oldWork.future;
        return syncComputeRunner(state);
      }

      final ledger = detailLedger(budgets: [detailBudget()]);
      final container = detailContainer(
        ledger: ledger,
        clock: DetailClock(october),
        runner: runner,
      );
      keepDetailAlive(container);
      await settledDetail(container);
      hold = true;
      ledger.addEntry(lunch(october));
      await pumpEventQueue();
      container.dispose();
      hold = false;
      final replacement = detailLedger(
        budgets: [detailBudget()],
        entries: [lunch(october, amount: '-7')],
      );
      final newContainer = detailContainer(
        ledger: replacement,
        clock: DetailClock(october),
        runner: runner,
      );
      keepDetailAlive(newContainer);
      final before = await settledDetail(newContainer);
      oldWork.complete(Accounting.analysisItems(ledger.state));
      final after = await settledDetail(newContainer);
      expect(after.spent, dec('7'));
      expect(after.projection, same(before.projection));
      expect(identical(after.ledger, replacement), isTrue);
    },
  );
}
