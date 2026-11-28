import 'package:spendwise/ledger/analysis/summaries/payable_cards.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';

// MARK: - Constants
const _dayUnit = 'day';
const _daysUnit = 'days';
const _closesPrefix = 'Closes ';

// MARK: - Types
class OverviewCardStatementRow {
  const OverviewCardStatementRow({
    required this.cardName,
    required this.payable,
    required this.daysToCut,
    required this.cutDate,
    required this.cycleAmount,
  });

  final String cardName;
  final String payable;
  final String daysToCut;
  final String cutDate;
  final String cycleAmount;

  @override
  bool operator ==(Object other) {
    return other is OverviewCardStatementRow &&
        other.cardName == cardName &&
        other.payable == payable &&
        other.daysToCut == daysToCut &&
        other.cutDate == cutDate &&
        other.cycleAmount == cycleAmount;
  }

  @override
  int get hashCode =>
      Object.hash(cardName, payable, daysToCut, cutDate, cycleAmount);
}

// MARK: - Card statements
List<OverviewCardStatementRow> overviewCardStatements(List<PayableCard> cards) {
  return [for (final card in cards) _cardStatementRow(card)];
}

OverviewCardStatementRow _cardStatementRow(PayableCard card) {
  final statement = card.statement;
  return OverviewCardStatementRow(
    cardName: card.accountName,
    payable: formatMoney(statement.payable),
    daysToCut: _daysToCutText(card.daysToCut),
    cutDate: '$_closesPrefix${formatDayMonthLong(statement.nextCut)}',
    cycleAmount: formatMoney(statement.cycleAmount),
  );
}

String _daysToCutText(int days) {
  if (days == 1) return '1 $_dayUnit';
  return '$days $_daysUnit';
}
