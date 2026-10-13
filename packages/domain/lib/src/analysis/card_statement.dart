import 'package:decimal/decimal.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/time/date_range.dart';
import 'package:meta/meta.dart';

// MARK: - Model

@immutable
class CardStatement {
  CardStatement({
    required String accountID,
    required this.currentCycle,
    required this.nextCut,
    required this.cycleAmount,
    required this.payable,
  }) : accountID = normalizedID(accountID);

  final String accountID;
  final DateRange currentCycle;
  final DateTime nextCut;
  final Decimal cycleAmount;
  final Decimal payable;

  // MARK: - Equality

  @override
  bool operator ==(Object other) {
    return other is CardStatement &&
        other.accountID == accountID &&
        other.currentCycle == currentCycle &&
        other.nextCut == nextCut &&
        other.cycleAmount == cycleAmount &&
        other.payable == payable;
  }

  @override
  int get hashCode =>
      Object.hash(accountID, currentCycle, nextCut, cycleAmount, payable);

  @override
  String toString() =>
      'CardStatement(accountID: $accountID, currentCycle: $currentCycle, '
      'nextCut: $nextCut, cycleAmount: $cycleAmount, payable: $payable)';
}
