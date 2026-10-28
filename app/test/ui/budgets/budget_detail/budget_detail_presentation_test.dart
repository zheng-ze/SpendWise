import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
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

  test('a budget with no counted entries anywhere is whole-budget fresh '
      'and hides the chart', () async {
    final presentation = await presentationFor(
      detailLedger(budgets: [detailBudget()]),
    );

    expect(presentation.body, BudgetDetailBody.content);
    expect(presentation.showsChart, isFalse);
    expect(presentation.emptyCopy?.title, 'No spending yet this month');
    expect(presentation.emptyCopy?.body, 'Add an expense to see it here.');
  });

  test('a category budget fresh state names its category', () async {
    final presentation = await presentationFor(
      detailLedger(budgets: [detailBudget(categoryID: foodCategory.id)]),
    );

    expect(presentation.showsChart, isFalse);
    expect(presentation.emptyCopy?.title, 'No Food spending yet this month');
    expect(
      presentation.emptyCopy?.body,
      'Choose Food when you add an expense.',
    );
  });

  test('an income entry does not count, so the budget stays fresh', () async {
    final income = Entry(
      amount: dec('500'),
      name: 'Salary',
      sourceID: checkingAccount.id,
      date: DateTime.utc(2026, 10, 1),
    );
    final presentation = await presentationFor(
      detailLedger(budgets: [detailBudget()], entries: [income]),
    );

    expect(presentation.showsChart, isFalse);
    expect(presentation.emptyCopy, isNotNull);
  });

  test('entries only in another year keep the chart and replace only the '
      'entries', () async {
    final presentation = await presentationFor(
      detailLedger(
        budgets: [detailBudget()],
        entries: [expense(DateTime.utc(2025, 10, 4))],
      ),
    );

    expect(presentation.showsChart, isTrue);
    expect(presentation.emptyCopy?.title, 'No spending yet this month');
  });

  test('entries in another month of the same year keep the chart and '
      'replace only the entries', () async {
    final presentation = await presentationFor(
      detailLedger(
        budgets: [detailBudget()],
        entries: [expense(DateTime.utc(2026, 9, 4))],
      ),
    );

    expect(presentation.showsChart, isTrue);
    expect(presentation.emptyCopy, isNotNull);
    expect(presentation.summary?.spent, dec('0'));
  });

  test(
    'a populated selected month shows the chart and no empty copy',
    () async {
      final presentation = await presentationFor(
        detailLedger(
          budgets: [detailBudget()],
          entries: [expense(DateTime.utc(2026, 10, 4))],
        ),
      );

      expect(presentation.showsChart, isTrue);
      expect(presentation.emptyCopy, isNull);
      expect(presentation.summary?.spent, dec('10'));
      expect(presentation.summary?.limit, dec('100'));
      expect(presentation.summary?.remaining, dec('90'));
    },
  );

  test('a deleted budget maps to the deleted body', () async {
    final presentation = await presentationFor(detailLedger());

    expect(presentation.body, BudgetDetailBody.deleted);
    expect(presentation.showsChart, isFalse);
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
}
