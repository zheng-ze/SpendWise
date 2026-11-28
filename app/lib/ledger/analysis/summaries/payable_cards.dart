import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

// MARK: - Items

@immutable
class PayableCard {
  const PayableCard({
    required this.accountName,
    required this.statement,
    required this.daysToCut,
  });

  final String accountName;
  final CardStatement statement;
  final int daysToCut;

  @override
  bool operator ==(Object other) {
    return other is PayableCard &&
        other.accountName == accountName &&
        other.statement == statement &&
        other.daysToCut == daysToCut;
  }

  @override
  int get hashCode => Object.hash(accountName, statement, daysToCut);

  @override
  String toString() =>
      'PayableCard(accountName: $accountName, statement: $statement, '
      'daysToCut: $daysToCut)';
}

// MARK: - Queries

List<PayableCard> payableCards({
  required LedgerState ledger,
  required DateTime today,
}) {
  final day = startOfDayUtc(today);
  final cards = <PayableCard>[];
  for (final source in ledger.moneySources.values) {
    final account = source.asAccount;
    if (account == null) continue;
    final statement = cardStatement(
      ledger: ledger,
      accountID: account.id,
      today: day,
    );
    if (statement == null || statement.payable <= Decimal.zero) continue;
    cards.add(
      PayableCard(
        accountName: account.name,
        statement: statement,
        daysToCut: statement.nextCut.difference(day).inDays,
      ),
    );
  }
  cards.sort(_byCutThenNameThenID);
  return List.unmodifiable(cards);
}

// MARK: - Sorting

int _byCutThenNameThenID(PayableCard a, PayableCard b) {
  final byCut = a.statement.nextCut.compareTo(b.statement.nextCut);
  if (byCut != 0) return byCut;
  final byName = a.accountName.compareTo(b.accountName);
  if (byName != 0) return byName;
  return a.statement.accountID.compareTo(b.statement.accountID);
}
