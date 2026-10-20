import 'package:domain/domain.dart';

import 'package:spendwise/ledger/ledger.dart';

const trendsFoodID = 'c0000000-0000-0000-0000-000000000001';
const trendsSourceID = 'a0000000-0000-0000-0000-000000000001';

final _food = TransactionCategory(
  id: trendsFoodID,
  name: 'Food',
  kind: CategoryKind.expense,
  colorHex: '#00AA00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
);

Ledger trendsLedger({bool withEntry = true}) {
  final account = Account(
    id: trendsSourceID,
    name: 'Checking',
    type: AccountType.checking,
  );
  final now = DateTime.now();
  final entry = Entry(
    amount: Decimal.parse('-12'),
    name: 'Lunch',
    sourceID: trendsSourceID,
    categoryID: trendsFoodID,
    date: DateTime.utc(now.year, now.month, 1),
  );
  return Ledger(
    state: LedgerState(
      moneySources: {trendsSourceID: MoneySource.account(account)},
      categories: {trendsFoodID: _food},
      entries: withEntry ? {entry.id: entry} : const {},
    ),
  );
}
