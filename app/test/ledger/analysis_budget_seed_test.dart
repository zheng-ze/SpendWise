import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_detail.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_overview.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

final _pinnedDay = DateTime.utc(2026, 10, 3);

Decimal dec(String value) => Decimal.parse(value);

Ledger seededLedger() {
  final state = LedgerState();
  buildSeed(state, today: _pinnedDay);
  return Ledger(state: state);
}

String categoryNamed(Ledger ledger, String name) =>
    ledger.state.categories.values.firstWhere((c) => c.name == name).id;

String sourceNamed(Ledger ledger, String name) =>
    ledger.state.moneySources.values.firstWhere((s) => s.name == name).id;

Decimal balanceOf(Ledger ledger, String name) {
  final id = sourceNamed(ledger, name);
  final booked = ledger.state.entries.values.where(
    (e) => !e.date.isAfter(_pinnedDay),
  );
  return Accounting.balance(
    of: id,
    entries: booked.toList(),
    sourceIDs: ledger.state.moneySources.keys.toSet(),
  );
}

void addSampleBudgets(Ledger ledger) {
  ledger.addBudget(null, dec('1200'));
  ledger.addBudget(categoryNamed(ledger, 'Dining'), dec('350'));
  ledger.addBudget(categoryNamed(ledger, 'Groceries'), dec('450'));
  ledger.addBudget(categoryNamed(ledger, 'Transport'), dec('120'));
}

Future<AnalysisQueries> queriesFor(Ledger ledger) async {
  final cache = AnalysisCache(runner: syncComputeRunner)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = AnalysisQueries(
    ledger: ledger,
    cache: cache,
    today: _pinnedDay,
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  await cache.refresh(ledger.state);
  return queries;
}

void main() {
  group('seed compatibility', () {
    test('keeps the Accounts and Plans figures the budgets build on', () {
      final ledger = seededLedger();
      final savings = ledger.state.moneySources.values
          .firstWhere((s) => s.name == 'OCBC Savings')
          .asAccount;

      expect(balanceOf(ledger, 'OCBC Savings'), dec('1700'));
      expect(balanceOf(ledger, 'Emergency Fund'), dec('8000'));
      expect(balanceOf(ledger, 'Holiday'), dec('650'));
      final total = Accounting.accountTotal(
        savings!,
        entries: ledger.state.entries.values.toList(),
        sourceIDs: ledger.state.moneySources.keys.toSet(),
        activePockets: ledger.state.moneySources.keys.toSet(),
      );
      expect(total, dec('10350'));
      expect(balanceOf(ledger, 'Amex Card'), dec('-325.10'));
      final anchors = {
        for (final plan in ledger.state.plans.values)
          plan.template.name: plan.anchor,
      };
      expect(anchors, {
        'Netflix': DateTime.utc(2026, 10, 20),
        'Monthly salary': DateTime.utc(2026, 10, 25),
      });
    });

    test('sample budgets reproduce the reference overview', () async {
      final ledger = seededLedger();
      addSampleBudgets(ledger);
      final queries = await queriesFor(ledger);

      final overview = queries.readBudgets(month: _pinnedDay).value;

      expect(overview?.allSpending.spent, dec('167.40'));
      expect(overview?.allSpending.cap, dec('1200'));
      expect(overview?.allSpending.remaining, dec('1032.60'));
      expect(
        overview?.allSpending.dailyAllowance?.round(scale: 2),
        dec('36.88'),
      );
      final rows = overview?.categoryBudgets ?? <CategoryBudgetRow>[];
      expect(
        [for (final r in rows) r.name],
        ['Dining', 'Groceries', 'Transport'],
      );
      expect(
        [for (final r in rows) r.spend],
        [dec('83.90'), dec('73.50'), dec('10.00')],
      );
      final percents = [
        for (final r in rows) (r.utilizationRatio * dec('100')).round(scale: 1),
      ];
      expect(percents, [dec('24.0'), dec('16.3'), dec('8.3')]);
    });

    test('a Dining budget reads one limit with 12 month slots', () async {
      final ledger = seededLedger();
      final dining = categoryNamed(ledger, 'Dining');
      ledger.addBudget(dining, dec('350'));
      final budgetID = ledger.state.budgets.values.single.id;
      final queries = await queriesFor(ledger);

      final detail = queries
          .readBudgetDetail(
            budgetID: budgetID,
            displayedYear: DateTime.utc(2026),
            selectedMonth: DateTime.utc(2026, 10),
          )
          .value;

      final slots = detail?.slots ?? <BudgetMonthSlot>[];
      expect(slots[7].recordCount, 0);
      expect(slots[7].completeness, PeriodCompleteness.complete);
      expect(slots[6].completeness, PeriodCompleteness.preRecord);
      expect(slots[9].completeness, PeriodCompleteness.incomplete);
      expect(slots[9].spend, dec('83.90'));
      expect(detail?.summary?.limit, dec('350'));
      expect(detail?.summary?.spent, dec('83.90'));
      expect(detail?.summary?.remaining, dec('266.10'));
    });
  });
}
