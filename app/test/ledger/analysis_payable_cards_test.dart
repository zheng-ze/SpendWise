import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/summaries/payable_cards.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

const _categoryID = '00000000-0000-4000-8000-0000000000c1';
const _incomeCategoryID = '00000000-0000-4000-8000-0000000000c2';
const _defaultStatementDay = 10;
final _may15 = DateTime.utc(2027, 5, 15);
final _owedDate = DateTime.utc(2027, 1, 1);

void _addCategory(Ledger ledger) {
  ledger.addCategory(
    TransactionCategory(
      id: _incomeCategoryID,
      name: 'Refund',
      kind: CategoryKind.income,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  ledger.addCategory(
    TransactionCategory(
      id: _categoryID,
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
}

Account _account(
  int n, {
  String? name,
  AccountType type = AccountType.card,
  int? statementDay = _defaultStatementDay,
}) => Account(
  id: testId(n),
  name: name ?? 'Account $n',
  type: type,
  statementDay: statementDay,
);

int _entryCounter = 0;

void _charge(Ledger ledger, int accountN, String amount, DateTime date) {
  _entryCounter++;
  ledger.addEntry(
    Entry(
      id: testId(900 + _entryCounter),
      amount: Decimal.parse(amount),
      name: 'charge',
      sourceID: testId(accountN),
      categoryID: amount.startsWith('-') ? _categoryID : _incomeCategoryID,
      date: date,
    ),
  );
}

void _addOwingCard(
  Ledger ledger,
  int n, {
  String? name,
  int statementDay = _defaultStatementDay,
  String owed = '-50.00',
}) {
  ledger.addAccount(_account(n, name: name, statementDay: statementDay));
  _charge(ledger, n, owed, _owedDate);
}

({Ledger ledger, AnalysisQueries queries}) _setup({DateTime? today}) {
  final setup = setupAnalysis(today: today ?? _may15);
  _addCategory(setup.ledger);
  return (ledger: setup.ledger, queries: setup.queries);
}

List<PayableCard> _cards(AnalysisQueries queries) =>
    queries.readPayableCards().value!;

List<int> _idNumbers(List<PayableCard> cards) => [
  for (final card in cards) int.parse(card.statement.accountID.split('-').last),
];

void main() {
  setUp(() => _entryCounter = 0);

  test('listsOwingCardsByNearestCutAndMatchesCardStatement', () {
    final setup = _setup();
    final ledger = setup.ledger;
    _addOwingCard(ledger, 1, statementDay: 20);
    _addOwingCard(ledger, 2, statementDay: 17);
    _addOwingCard(ledger, 3, statementDay: 10);

    final cards = _cards(setup.queries);

    expect(_idNumbers(cards), [2, 1, 3]);
    for (final card in cards) {
      final read = setup.queries.readCardStatement(
        accountID: card.statement.accountID,
      );
      expect(card.statement, read.value);
    }
  });

  test('equalCutsOrderByNameThenID', () {
    final setup = _setup();
    final ledger = setup.ledger;
    _addOwingCard(ledger, 3, name: 'Zeta');
    _addOwingCard(ledger, 2, name: 'Alpha');
    _addOwingCard(ledger, 1, name: 'Alpha');

    final cards = _cards(setup.queries);

    expect(_idNumbers(cards), [1, 2, 3]);
    expect(cards.map((card) => card.accountName), ['Alpha', 'Alpha', 'Zeta']);
  });

  test('binnedCardAndCardWithoutStatementDayAreExcluded', () {
    final setup = _setup();
    final ledger = setup.ledger;
    _addOwingCard(ledger, 1);
    _addOwingCard(ledger, 2);
    ledger.deleteAccount(testId(2));
    ledger.addAccount(_account(3, statementDay: null));
    _charge(ledger, 3, '-50.00', _owedDate);

    final cards = _cards(setup.queries);

    expect(_idNumbers(cards), [1]);
  });

  test('zeroPayableCardIsExcluded', () {
    final setup = _setup();
    final ledger = setup.ledger;
    _addOwingCard(ledger, 1);
    _addOwingCard(ledger, 2, owed: '25.00');
    ledger.addAccount(_account(3));

    final cards = _cards(setup.queries);

    expect(_idNumbers(cards), [1]);
  });

  test('noEligibleCardGivesEmptyReadyList', () {
    final setup = _setup();
    setup.ledger.addAccount(_account(1, type: AccountType.checking));

    final result = setup.queries.readPayableCards();

    expect(result.state, AnalysisQueryState.ready);
    expect(result.value, isEmpty);
  });

  test('onlyZeroPayableCardsGiveEmptyList', () {
    final setup = _setup();
    final ledger = setup.ledger;
    ledger.addAccount(_account(1));
    _addOwingCard(ledger, 2, owed: '10.00');

    expect(setup.queries.readPayableCards().value, isEmpty);
  });

  test('sixCardsAreAllReturnedWithNoCap', () {
    final setup = _setup();
    for (var n = 1; n <= 6; n++) {
      _addOwingCard(setup.ledger, n, statementDay: 16 + n);
    }

    final cards = _cards(setup.queries);

    expect(_idNumbers(cards), [1, 2, 3, 4, 5, 6]);
  });

  test('statementDayReportsNextMonthCutAndNeverZeroDays', () {
    final setup = _setup();
    _addOwingCard(setup.ledger, 1, statementDay: 15);

    final card = (_cards(setup.queries)).single;

    expect(card.statement.nextCut, DateTime.utc(2027, 6, 15));
    expect(card.daysToCut, 31);
  });

  test('dayBeforeTheCutGivesOneDay', () {
    final setup = _setup(today: DateTime.utc(2027, 5, 14));
    _addOwingCard(setup.ledger, 1, statementDay: 15);

    final card = (_cards(setup.queries)).single;

    expect(card.statement.nextCut, DateTime.utc(2027, 5, 15));
    expect(card.daysToCut, 1);
  });

  test('decemberRollsTheCutIntoJanuary', () {
    final setup = _setup(today: DateTime.utc(2027, 12, 20));
    _addOwingCard(setup.ledger, 1, statementDay: 10);

    final card = (_cards(setup.queries)).single;

    expect(card.statement.nextCut, DateTime.utc(2028, 1, 10));
    expect(card.daysToCut, 21);
  });

  test('statementDay28InFebruaryCutsOnTheTwentyEighth', () {
    final setup = _setup(today: DateTime.utc(2027, 2, 10));
    _addOwingCard(setup.ledger, 1, statementDay: 28);

    final card = (_cards(setup.queries)).single;

    expect(card.statement.nextCut, DateTime.utc(2027, 2, 28));
    expect(card.daysToCut, 18);
  });

  test('checkingAndSavingsAccountsAreNeverListed', () {
    final setup = _setup();
    final ledger = setup.ledger;
    ledger.addAccount(_account(1, type: AccountType.checking));
    ledger.addAccount(_account(2, type: AccountType.savings));
    _charge(ledger, 1, '-50.00', _owedDate);
    _charge(ledger, 2, '-50.00', _owedDate);

    expect(setup.queries.readPayableCards().value, isEmpty);
  });

  test('chargeOnTheCutDateIsNotPayableAndDoesNotListTheCard', () {
    final setup = _setup();
    final ledger = setup.ledger;
    final cutDate = DateTime.utc(2027, 5, 20);
    ledger.addAccount(_account(1, statementDay: 20));
    _charge(ledger, 1, '-100.00', cutDate);
    _addOwingCard(ledger, 2, statementDay: 20, owed: '-30.00');
    _charge(ledger, 2, '-100.00', cutDate);
    _charge(ledger, 2, '-100.00', cutDate.add(const Duration(days: 5)));

    final cards = _cards(setup.queries);

    expect(_idNumbers(cards), [2]);
    expect(cards.single.statement.payable, Decimal.parse('30.00'));
  });

  test('isReadyWhileAnalysisPendingAndCarriesLedgerRevision', () {
    final setup = setupAnalysis(today: _may15);
    _addCategory(setup.ledger);
    _addOwingCard(setup.ledger, 1);

    final result = setup.queries.readPayableCards();

    expect(setup.runner.pending, isNotEmpty);
    expect(result.state, AnalysisQueryState.ready);
    expect(result.sourceRevision, setup.ledger.revision);
    expect(result.value, hasLength(1));
  });

  test('identicalSecondReadReusesTheMemo', () {
    final setup = _setup();
    _addOwingCard(setup.ledger, 1);

    final first = setup.queries.readPayableCards();

    expect(identical(setup.queries.readPayableCards(), first), isTrue);
  });

  test('renamingTheCardRecomputesAccountName', () {
    final setup = _setup();
    _addOwingCard(setup.ledger, 1, name: 'Old');
    final before = setup.queries.readPayableCards();

    setup.ledger.updateAccount(_account(1, name: 'New'));
    final after = setup.queries.readPayableCards();

    expect(before.value!.single.accountName, 'Old');
    expect(after.value!.single.accountName, 'New');
  });

  test('setTodayRecomputesDaysToCut', () {
    final setup = _setup();
    _addOwingCard(setup.ledger, 1, statementDay: 20);
    final before = _cards(setup.queries);

    setup.queries.setToday(DateTime.utc(2027, 5, 16));
    final after = _cards(setup.queries);

    expect(before.single.daysToCut, 5);
    expect(after.single.daysToCut, 4);
  });
}
