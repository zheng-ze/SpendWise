import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/swipe_to_delete_row.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.row,
    required this.ledger,
    required this.state,
  });

  final TransactionRow row;
  final Ledger ledger;
  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    final entry = state.entries[row.id];
    if (entry == null) return const SizedBox.shrink();

    return SwipeToDeleteRow(
      itemKey: ValueKey(entry.id),
      itemName: row.title,
      onDeleted: () => ledger.deleteEntry(entry.id),
      child: TransactionCell(
        row: row,
        onTap: () => showEntryFormSheet(context: context, entryId: entry.id),
      ),
    );
  }
}
