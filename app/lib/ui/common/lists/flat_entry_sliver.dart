import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/daily_list/entry_row.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

class FlatEntrySliver extends StatelessWidget {
  const FlatEntrySliver({
    super.key,
    required this.rows,
    required this.ledger,
    required this.state,
  });

  final List<TransactionRow> rows;
  final Ledger ledger;
  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return EntryRow(
          key: ValueKey(row.id),
          row: row,
          ledger: ledger,
          state: state,
        );
      },
    );
  }
}
