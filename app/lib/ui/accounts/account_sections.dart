import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:spendwise/ui/accounts/card_math.dart';

const _sectionOrder = [
  AccountType.cash,
  AccountType.checking,
  AccountType.savings,
  AccountType.card,
  AccountType.prepaid,
  AccountType.investment,
  AccountType.insurance,
  AccountType.other,
];

@immutable
sealed class RowAmount {
  const RowAmount();
}

@immutable
class SingleTotal extends RowAmount {
  const SingleTotal(this.total);

  final Decimal total;
}

@immutable
class CardAmounts extends RowAmount {
  const CardAmounts({required this.payable, required this.outstanding});

  final Decimal payable;
  final Decimal outstanding;
}

@immutable
class PocketRow {
  const PocketRow({
    required this.id,
    required this.name,
    required this.balance,
  });

  final String id;
  final String name;
  final Decimal balance;
}

@immutable
class AccountRow {
  const AccountRow({
    required this.id,
    required this.name,
    required this.amount,
    required this.ownBalance,
    required this.pockets,
  });

  final String id;
  final String name;
  final RowAmount amount;
  final Decimal ownBalance;
  final List<PocketRow> pockets;
}

@immutable
sealed class SectionHeader {
  const SectionHeader();
}

@immutable
class SubtotalHeader extends SectionHeader {
  const SubtotalHeader(this.subtotal);

  final Decimal subtotal;
}

@immutable
class CardHeader extends SectionHeader {
  const CardHeader({required this.payable, required this.outstanding});

  final Decimal payable;
  final Decimal outstanding;
}

@immutable
class AccountSection {
  const AccountSection({
    required this.type,
    required this.rows,
    required this.header,
  });

  final AccountType type;
  final List<AccountRow> rows;
  final SectionHeader header;
}

List<AccountSection> accountSections(
  LedgerState state, {
  required DateTime now,
}) {
  final sourceIDs = state.moneySources.keys.toSet();
  final activePockets = state.activeSources;
  final entries = state.entries.values.toList();

  final byType = <AccountType, List<Account>>{};
  for (final account in state.activeAccounts) {
    (byType[account.type] ??= []).add(account);
  }

  final sections = <AccountSection>[];
  for (final type in _sectionOrder) {
    final accounts = byType[type];
    if (accounts == null || accounts.isEmpty) continue;

    final rows = [
      for (final account in accounts)
        _row(
          account,
          state: state,
          entries: entries,
          sourceIDs: sourceIDs,
          activePockets: activePockets,
          now: now,
        ),
    ];

    sections.add(
      AccountSection(type: type, rows: rows, header: _header(type, rows)),
    );
  }
  return sections;
}

AccountRow _row(
  Account account, {
  required LedgerState state,
  required List<Entry> entries,
  required Set<String> sourceIDs,
  required Set<String> activePockets,
  required DateTime now,
}) {
  final total = Accounting.accountTotal(
    account,
    entries: entries,
    sourceIDs: sourceIDs,
    activePockets: activePockets,
  );
  final ownBalance = Accounting.balance(
    of: account.id,
    entries: entries,
    sourceIDs: sourceIDs,
  );

  final pockets = [
    for (final pocket in state.activePockets(account))
      PocketRow(
        id: pocket.id,
        name: pocket.name,
        balance: Accounting.balance(
          of: pocket.id,
          entries: entries,
          sourceIDs: sourceIDs,
        ),
      ),
  ];

  final amount = account.type == AccountType.card
      ? CardAmounts(
          payable: payable(total),
          outstanding: outstanding(
            entries,
            account.id,
            statementCut(account.statementDay ?? 1, now),
            now,
          ),
        )
      : SingleTotal(total);

  return AccountRow(
    id: account.id,
    name: account.name,
    amount: amount,
    ownBalance: ownBalance,
    pockets: pockets,
  );
}

SectionHeader _header(AccountType type, List<AccountRow> rows) {
  if (type == AccountType.card) {
    var payableSum = Decimal.zero;
    var outstandingSum = Decimal.zero;
    for (final row in rows) {
      final amount = row.amount as CardAmounts;
      payableSum += amount.payable;
      outstandingSum += amount.outstanding;
    }
    return CardHeader(payable: payableSum, outstanding: outstandingSum);
  }

  var subtotal = Decimal.zero;
  for (final row in rows) {
    subtotal += (row.amount as SingleTotal).total;
  }
  return SubtotalHeader(subtotal);
}
