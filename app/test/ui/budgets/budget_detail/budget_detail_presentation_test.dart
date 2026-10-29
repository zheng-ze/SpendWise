import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_detail.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/charts/month_bars.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_presentation.dart';

import 'budget_detail_test_support.dart';

void main() {
  final october = DateTime.utc(2026, 10, 28);

  Entry expense(DateTime date, {String amount = '-10'}) => Entry(
    amount: dec(amount),
    name: 'Lunch',
    sourceID: checkingAccount.id,
    date: date,
  );

  Future<BudgetDetailPresentation> presentationFor(Ledger ledger) async {
    final container = detailContainer(
      ledger: ledger,
      clock: DetailClock(october),
    );
    keepDetailAlive(container);
    final state = await settledDetail(container);
    return budgetDetailPresentation(state);
  }

  test(
    'a budget with no counted entries shows the empty entries message',
    () async {
      final presentation = await presentationFor(
        detailLedger(budgets: [detailBudget()]),
      );

      expect(presentation.body, BudgetDetailBody.content);
      expect(presentation.emptyCopy?.title, 'No spending yet this month');
      expect(presentation.emptyCopy?.body, 'Add an expense to see it here.');
    },
  );

  test('a category budget empty entries message names its category', () async {
    final presentation = await presentationFor(
      detailLedger(budgets: [detailBudget(categoryID: foodCategory.id)]),
    );
    expect(presentation.emptyCopy?.title, 'No Food spending yet this month');
    expect(
      presentation.emptyCopy?.body,
      'Choose Food when you add an expense.',
    );
  });

  test('an income entry does not count, so the entries stay empty', () async {
    final income = Entry(
      amount: dec('500'),
      name: 'Salary',
      sourceID: checkingAccount.id,
      date: DateTime.utc(2026, 10, 1),
    );
    final presentation = await presentationFor(
      detailLedger(budgets: [detailBudget()], entries: [income]),
    );
    expect(presentation.emptyCopy, isNotNull);
  });

  test('entries only in another year give the selected month the empty '
      'message', () async {
    final presentation = await presentationFor(
      detailLedger(
        budgets: [detailBudget()],
        entries: [expense(DateTime.utc(2025, 10, 4))],
      ),
    );
    expect(presentation.emptyCopy?.title, 'No spending yet this month');
  });

  test('entries in another month of the same year give the selected month the '
      'empty message', () async {
    final presentation = await presentationFor(
      detailLedger(
        budgets: [detailBudget()],
        entries: [expense(DateTime.utc(2026, 9, 4))],
      ),
    );
    expect(presentation.emptyCopy, isNotNull);
    expect(presentation.summary?.spent, dec('0'));
  });

  test('a populated selected month has no empty copy', () async {
    final presentation = await presentationFor(
      detailLedger(
        budgets: [detailBudget()],
        entries: [expense(DateTime.utc(2026, 10, 4))],
      ),
    );
    expect(presentation.emptyCopy, isNull);
    expect(presentation.summary?.spent, dec('10'));
    expect(presentation.summary?.limit, dec('100'));
    expect(presentation.summary?.remaining, dec('90'));
  });

  test('a deleted budget maps to the deleted body', () async {
    final presentation = await presentationFor(detailLedger());

    expect(presentation.body, BudgetDetailBody.deleted);
    expect(presentation.summary, isNull);
  });

  test('the initial pending read maps to the skeleton body', () {
    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
    );
    keepDetailAlive(container);

    final presentation = budgetDetailPresentation(detailState(container));

    expect(presentation.body, BudgetDetailBody.skeleton);
    expect(presentation.failure, isNull);
    expect(presentation.summary, isNull);
  });

  test('an initial failure maps to the failure body with its reason', () async {
    Future<List<AnalysisItem>> failingRunner(LedgerState state) async {
      throw StateError('compute unavailable');
    }

    final container = detailContainer(
      ledger: detailLedger(budgets: [detailBudget()]),
      clock: DetailClock(october),
      runner: failingRunner,
    );
    keepDetailAlive(container);

    final state = await settledDetail(container);
    final presentation = budgetDetailPresentation(state);

    expect(presentation.body, BudgetDetailBody.failure);
    expect('${presentation.failure}', contains('compute unavailable'));
  });

  test('summary progress is spent over limit and clamps at full', () {
    BudgetDetailSummaryValues summary(String spent, String limit) =>
        BudgetDetailSummaryValues(spent: dec(spent), limit: dec(limit));

    expect(summary('25', '100').progress, closeTo(0.25, 1e-9));
    expect(summary('150', '100').progress, 1.0);
    expect(summary('150', '100').overLimit, isTrue);
    expect(summary('10', '0').progress, 0.0);
  });

  test('empty copy without a category uses the overall wording', () {
    final copy = budgetDetailEmptyCopy(null);

    expect(copy.title, 'No spending yet this month');
    expect(copy.body, 'Add an expense to see it here.');
  });

  BudgetMonthSlot monthSlot({
    required String spend,
    required int recordCount,
    required PeriodCompleteness completeness,
  }) => BudgetMonthSlot(
    month: const YearMonth(2026, 10),
    spend: dec(spend),
    limit: dec('100'),
    isOverride: false,
    recordCount: recordCount,
    completeness: completeness,
  );

  test('a month before the first record maps to a blank bar', () {
    final slot = budgetMonthBarSlot(
      monthSlot(
        spend: '0',
        recordCount: 0,
        completeness: PeriodCompleteness.preRecord,
      ),
    );

    expect(slot.status, MonthBarStatus.blank);
  });

  test('a complete month with no records maps to a gap stub', () {
    final slot = budgetMonthBarSlot(
      monthSlot(
        spend: '0',
        recordCount: 0,
        completeness: PeriodCompleteness.complete,
      ),
    );

    expect(slot.status, MonthBarStatus.gap);
  });

  test('a complete month with records keeps its spend as the value', () {
    final slot = budgetMonthBarSlot(
      monthSlot(
        spend: '42',
        recordCount: 2,
        completeness: PeriodCompleteness.complete,
      ),
    );

    expect(slot.status, MonthBarStatus.value);
    expect(slot.value, 42.0);
  });

  test('an incomplete month with records is marked incomplete with its '
      'committed spend and no forecast', () {
    final slot = budgetMonthBarSlot(
      monthSlot(
        spend: '42',
        recordCount: 2,
        completeness: PeriodCompleteness.incomplete,
      ),
    );

    expect(slot.status, MonthBarStatus.incomplete);
    expect(slot.value, 42.0);
  });

  test('a future month with no records stays blank and is not forecast', () {
    final slot = budgetMonthBarSlot(
      monthSlot(
        spend: '0',
        recordCount: 0,
        completeness: PeriodCompleteness.incomplete,
      ),
    );

    expect(slot.status, MonthBarStatus.blank);
    expect(slot.value, 0.0);
  });
}
