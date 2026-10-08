import 'package:decimal/decimal.dart';
import 'package:domain/src/accounting.dart';
import 'package:domain/src/accounts/account_type.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/ledger_state/ledger_state.dart';
import 'package:domain/src/time/calendar_day.dart';
import 'package:domain/src/time/date_range.dart';
import 'package:meta/meta.dart';

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

CardStatement? cardStatement({
  required LedgerState ledger,
  required String accountID,
  required DateTime today,
}) {
  final id = normalizedID(accountID);
  final day = startOfDayUtc(today);
  final account = ledger.moneySources[id]?.asAccount;
  final statementDay = account?.statementDay;
  if (account == null ||
      !account.lifecycle.isActive ||
      account.type != AccountType.card ||
      statementDay == null) {
    return null;
  }

  final monthAnchor = DateTime.utc(day.year, day.month);
  final thisMonthCut = shiftMonthThenClampDayUtc(
    monthAnchor,
    0,
    day: statementDay,
  );
  final DateTime cycleStart;
  final DateTime nextCut;
  if (day.isBefore(thisMonthCut)) {
    cycleStart = shiftMonthThenClampDayUtc(monthAnchor, -1, day: statementDay);
    nextCut = thisMonthCut;
  } else {
    cycleStart = thisMonthCut;
    nextCut = shiftMonthThenClampDayUtc(monthAnchor, 1, day: statementDay);
  }

  final entries = ledger.entries.values.toList();
  final payableEntries = [
    for (final entry in entries)
      if (entry.lifecycle.isActive && entry.date.isBefore(nextCut)) entry,
  ];
  final total = Accounting.accountTotal(
    account,
    entries: payableEntries,
    sourceIDs: ledger.moneySources.keys.toSet(),
    activePockets: ledger.activeSources,
  );
  final payable = total >= Decimal.zero ? Decimal.zero : -total;

  final observedEnd = nextCut.isBefore(day.add(const Duration(days: 1)))
      ? nextCut
      : day.add(const Duration(days: 1));
  var cycleAmount = Decimal.zero;
  for (final entry in entries) {
    if (!entry.lifecycle.isActive ||
        entry.sourceID != account.id ||
        entry.isTransfer ||
        entry.amount >= Decimal.zero ||
        entry.date.isBefore(cycleStart) ||
        !entry.date.isBefore(observedEnd)) {
      continue;
    }
    cycleAmount -= entry.amount;
  }

  return CardStatement(
    accountID: id,
    currentCycle: DateRange(cycleStart, nextCut),
    nextCut: nextCut,
    cycleAmount: cycleAmount,
    payable: payable,
  );
}
