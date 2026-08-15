import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/symbol_map.dart';

class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) => _RecycleBinScreenBody(ledger: ledger),
    );
  }
}

enum _BinRowKind { account, pocket, category }

class _BinRow {
  const _BinRow({
    required this.kind,
    required this.id,
    required this.name,
    required this.referenceCount,
    this.symbolName,
    this.color,
  });

  final _BinRowKind kind;
  final String id;
  final String name;
  final int referenceCount;
  final String? symbolName;
  final Color? color;
}

List<_BinRow> _sortedArchivedRows<T>(
  Iterable<T> source,
  bool Function(T item) isArchived,
  _BinRow Function(T item) toRow,
) {
  final rows = source.where(isArchived).map(toRow).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return rows;
}

List<_BinRow> _accountRows(LedgerState state) => _sortedArchivedRows(
  state.moneySources.values.map((source) => source.asAccount).nonNulls,
  (account) => account.lifecycle == LifecycleState.archived,
  (account) => _BinRow(
    kind: _BinRowKind.account,
    id: account.id,
    name: account.name,
    referenceCount: state.entriesReferencing(account.id),
  ),
);

List<_BinRow> _pocketRows(LedgerState state) => _sortedArchivedRows(
  state.moneySources.values.map((source) => source.asPocket).nonNulls,
  (pocket) => pocket.lifecycle == LifecycleState.archived,
  (pocket) => _BinRow(
    kind: _BinRowKind.pocket,
    id: pocket.id,
    name: state.sourceName(pocket.id) ?? pocket.name,
    referenceCount: state.entriesReferencing(pocket.id),
  ),
);

List<_BinRow> _categoryRows(LedgerState state) => _sortedArchivedRows(
  state.categories.values,
  (category) => category.lifecycle == LifecycleState.archived,
  (category) => _BinRow(
    kind: _BinRowKind.category,
    id: category.id,
    name: category.name,
    referenceCount: state.entryCountReferencing(category.id),
    symbolName: category.symbol,
    color: parseColorHex(category.colorHex),
  ),
);

class _RecycleBinScreenBody extends StatelessWidget {
  const _RecycleBinScreenBody({required this.ledger});

  final Ledger ledger;

  Future<bool> _confirmPurge(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          '$name leaves the bin for good. Existing transactions keep the '
          'name but it can no longer be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _restore(_BinRow row) {
    switch (row.kind) {
      case _BinRowKind.account:
        ledger.restoreAccount(row.id);
      case _BinRowKind.pocket:
        // Domain no-ops silently when the pocket's parent account is still
        // archived, so the row simply stays put.
        ledger.restorePocket(row.id);
      case _BinRowKind.category:
        ledger.restoreCategory(row.id);
    }
  }

  void _purge(_BinRow row) {
    switch (row.kind) {
      case _BinRowKind.account:
        ledger.purgeAccount(row.id);
      case _BinRowKind.pocket:
        ledger.purgePocket(row.id);
      case _BinRowKind.category:
        ledger.purgeCategory(row.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ledger.state;
    final accounts = _accountRows(state);
    final pockets = _pocketRows(state);
    final categories = _categoryRows(state);

    final isEmpty = accounts.isEmpty && pockets.isEmpty && categories.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Recycle bin')),
      body: SafeArea(
        child: isEmpty
            ? const _EmptyState()
            : ListView(
                children: [
                  if (accounts.isNotEmpty)
                    _BinSection(
                      title: 'Accounts',
                      sectionIcon: symbolIcon('wallet'),
                      rows: accounts,
                      onRestore: (row) => _restore(row),
                      onConfirmPurge: (row) => _confirmPurge(context, row.name),
                      onPurge: (row) => _purge(row),
                    ),
                  if (pockets.isNotEmpty)
                    _BinSection(
                      title: 'Subpockets',
                      sectionIcon: symbolIcon('inbox'),
                      rows: pockets,
                      onRestore: (row) => _restore(row),
                      onConfirmPurge: (row) => _confirmPurge(context, row.name),
                      onPurge: (row) => _purge(row),
                    ),
                  if (categories.isNotEmpty)
                    _BinSection(
                      title: 'Categories',
                      sectionIcon: null,
                      rows: categories,
                      onRestore: (row) => _restore(row),
                      onConfirmPurge: (row) => _confirmPurge(context, row.name),
                      onPurge: (row) => _purge(row),
                    ),
                ],
              ),
      ),
    );
  }
}

class _BinSection extends StatelessWidget {
  const _BinSection({
    required this.title,
    required this.sectionIcon,
    required this.rows,
    required this.onRestore,
    required this.onConfirmPurge,
    required this.onPurge,
  });

  final String title;
  final IconData? sectionIcon;
  final List<_BinRow> rows;
  final void Function(_BinRow row) onRestore;
  final Future<bool> Function(_BinRow row) onConfirmPurge;
  final void Function(_BinRow row) onPurge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final row in rows)
          _BinRowTile(
            row: row,
            sectionIcon: sectionIcon,
            onRestore: () => onRestore(row),
            onConfirmPurge: () => onConfirmPurge(row),
            onPurge: () => onPurge(row),
          ),
      ],
    );
  }
}

class _BinRowTile extends StatelessWidget {
  const _BinRowTile({
    required this.row,
    required this.sectionIcon,
    required this.onRestore,
    required this.onConfirmPurge,
    required this.onPurge,
  });

  final _BinRow row;
  final IconData? sectionIcon;
  final VoidCallback onRestore;
  final Future<bool> Function() onConfirmPurge;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final referenceLabel = row.referenceCount == 1
        ? '1 reference'
        : '${row.referenceCount} references';

    return Dismissible(
      key: ValueKey('bin-${row.kind}-${row.id}'),
      direction: DismissDirection.horizontal,
      background: const _RestoreBackground(),
      secondaryBackground: const _PurgeBackground(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onRestore();
          return false;
        }
        final confirmed = await onConfirmPurge();
        if (confirmed) onPurge();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            row.symbolName != null
                ? CategoryIcon(
                    symbolName: row.symbolName!,
                    color: row.color ?? colorHexFallback,
                    size: 28,
                  )
                : Icon(sectionIcon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(row.name, style: theme.textTheme.bodyLarge)),
            Text(
              referenceLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreBackground extends StatelessWidget {
  const _RestoreBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(symbolIcon('undo'), color: Colors.white),
    );
  }
}

class _PurgeBackground extends StatelessWidget {
  const _PurgeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Recycle bin is empty',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
