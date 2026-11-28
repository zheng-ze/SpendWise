import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/summaries/payable_cards.dart';
import 'package:spendwise/ui/overview/overview_card_statement_mapping.dart';

const _firstCardID = '11111111-1111-4111-8111-111111111111';
const _secondCardID = '22222222-2222-4222-8222-222222222222';

Decimal _d(String value) => Decimal.parse(value);

PayableCard _card({
  String name = 'Visa',
  String accountID = _firstCardID,
  String payable = '399.60',
  String cycleAmount = '285.10',
  int daysToCut = 12,
  DateTime? nextCut,
}) => PayableCard(
  accountName: name,
  daysToCut: daysToCut,
  statement: CardStatement(
    accountID: accountID,
    currentCycle: DateRange(
      DateTime.utc(2026, 9, 16),
      DateTime.utc(2026, 10, 15),
    ),
    nextCut: nextCut ?? DateTime.utc(2026, 10, 15),
    cycleAmount: _d(cycleAmount),
    payable: _d(payable),
  ),
);

void main() {
  test('formats payable and cycle amount as money', () {
    final row = overviewCardStatements([_card()]).single;

    expect(row.cardName, 'Visa');
    expect(row.payable, 'S\$399.60');
    expect(row.cycleAmount, 'S\$285.10');
  });

  test('words several days to the cut in the plural', () {
    final row = overviewCardStatements([_card(daysToCut: 12)]).single;

    expect(row.daysToCut, '12 days');
  });

  test('words one day to the cut in the singular', () {
    final row = overviewCardStatements([_card(daysToCut: 1)]).single;

    expect(row.daysToCut, '1 day');
  });

  test('words the cut date as Closes day and month', () {
    final row = overviewCardStatements([_card()]).single;

    expect(row.cutDate, 'Closes 15 October');
  });

  test('keeps the input order', () {
    final rows = overviewCardStatements([
      _card(name: 'Visa'),
      _card(name: 'Amex', accountID: _secondCardID),
    ]);

    expect(rows.map((row) => row.cardName), ['Visa', 'Amex']);
  });

  test('maps no cards to no rows', () {
    expect(overviewCardStatements(const []), isEmpty);
  });
}
