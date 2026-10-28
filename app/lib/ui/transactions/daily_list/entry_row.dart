import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - EntryRow
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.row,
    required this.ledger,
    required this.state,
    this.registerStyle = false,
    this.isLastInDay = false,
  });

  final TransactionRow row;
  final Ledger ledger;
  final LedgerState state;
  final bool registerStyle;
  final bool isLastInDay;

  @override
  Widget build(BuildContext context) {
    final entry = state.entries[row.id];
    if (entry == null) return const SizedBox.shrink();

    void onTap() => showEntryFormSheet(context: context, entryId: entry.id);
    final cell = registerStyle
        ? TransactionCell.register(
            row: row,
            onTap: onTap,
            isLastInDay: isLastInDay,
          )
        : TransactionCell(row: row, onTap: onTap);

    return SwipeRow(
      itemKey: ValueKey(entry.id),
      itemName: row.title,
      onDeleted: () => ledger.deleteEntry(entry.id),
      child: cell,
    );
  }
}
