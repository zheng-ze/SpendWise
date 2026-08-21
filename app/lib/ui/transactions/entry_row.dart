import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/delete_confirmation.dart';
import 'package:spendwise/ui/transactions/entry_form.dart';
import 'package:spendwise/ui/transactions/transaction_cell.dart';
import 'package:spendwise/ui/transactions/transaction_row.dart';

/// One entry in a scoped list (a budget's or category's entry list): tap
/// opens the entry, swipe or the equivalent semantic action deletes it after
/// confirmation.
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

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Delete ${row.title}'): () async {
          if (await showDeleteConfirmation(
            context,
            note: row.note,
            title: row.title,
          )) {
            ledger.deleteEntry(entry.id);
          }
        },
      },
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Theme.of(context).colorScheme.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        confirmDismiss: (_) =>
            showDeleteConfirmation(context, note: row.note, title: row.title),
        onDismissed: (_) => ledger.deleteEntry(entry.id),
        child: TransactionCell(
          row: row,
          onTap: () => showEntryFormSheet(
            context: context,
            ledger: ledger,
            entry: entry,
          ),
        ),
      ),
    );
  }
}
