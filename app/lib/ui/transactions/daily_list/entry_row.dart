import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

// MARK: - EntryRow
class EntryRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = state.entries[row.id];
    if (entry == null) return const SizedBox.shrink();

    return SwipeRow(
      itemKey: ValueKey(entry.id),
      itemName: row.title,
      onDeleted: () => ledger.deleteEntry(entry.id),
      child: TransactionCell(
        row: row,
        onTap: () =>
            openEditEntry(context: context, ref: ref, entryId: entry.id),
      ),
    );
  }
}
