import 'package:domain/domain.dart';

DateTime statementCut(int statementDay, DateTime now) {
  final anchorsPreviousMonth = now.day < statementDay;
  final anchor = anchorsPreviousMonth
      ? DateTime.utc(now.year, now.month - 1)
      : DateTime.utc(now.year, now.month);

  return shiftMonthThenClampDayUtc(anchor, 0, day: statementDay);
}

Decimal payable(Decimal accountTotal) {
  final negated = -accountTotal;
  return negated < Decimal.zero ? Decimal.zero : negated;
}

Decimal outstanding(
  List<Entry> entries,
  String accountID,
  DateTime cut,
  DateTime now,
) {
  var total = Decimal.zero;
  for (final entry in entries) {
    if (entry.sourceID != accountID) continue;
    if (entry.isTransfer) continue;
    if (entry.amount >= Decimal.zero) continue;
    if (entry.date.isBefore(cut) || entry.date.isAfter(now)) continue;

    total -= entry.amount;
  }
  return total;
}
