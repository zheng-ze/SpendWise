import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/symbol_map.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  ProviderSubscription<AsyncValue<RecycleBinViewState>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      recycleBinViewModelProvider,
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  RecycleBinViewModel get _viewModel =>
      ref.read(recycleBinViewModelProvider.notifier);

  void _handleStep(RecycleBinStep? step) {
    if (step == null) return;
    switch (step) {
      case PurgeConfirmationRequested(:final row):
        _confirmPurge(row);
    }
  }

  Future<void> _confirmPurge(BinRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          '${row.name} leaves the bin for good. Existing transactions keep '
          'the name but it can no longer be restored.',
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
    if (!mounted) return;
    _viewModel.applyPurgeConfirmed(confirmed ?? false, row.kind, row.id);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(recycleBinViewModelProvider);

    return asyncState.when(
      data: (viewState) =>
          _RecycleBinScreenBody(viewState: viewState, viewModel: _viewModel),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _RecycleBinScreenBody extends StatelessWidget {
  const _RecycleBinScreenBody({
    required this.viewState,
    required this.viewModel,
  });

  final RecycleBinViewState viewState;
  final RecycleBinViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final accounts = viewState.accounts;
    final pockets = viewState.pockets;
    final categories = viewState.categories;

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
                      onRestore: (row) => viewModel.restore(row.kind, row.id),
                      onRequestPurge: (row) => viewModel.requestPurge(row),
                    ),
                  if (pockets.isNotEmpty)
                    _BinSection(
                      title: 'Subpockets',
                      sectionIcon: symbolIcon('inbox'),
                      rows: pockets,
                      onRestore: (row) => viewModel.restore(row.kind, row.id),
                      onRequestPurge: (row) => viewModel.requestPurge(row),
                    ),
                  if (categories.isNotEmpty)
                    _BinSection(
                      title: 'Categories',
                      sectionIcon: null,
                      rows: categories,
                      onRestore: (row) => viewModel.restore(row.kind, row.id),
                      onRequestPurge: (row) => viewModel.requestPurge(row),
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
    required this.onRequestPurge,
  });

  final String title;
  final IconData? sectionIcon;
  final List<BinRow> rows;
  final void Function(BinRow row) onRestore;
  final void Function(BinRow row) onRequestPurge;

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
            onRequestPurge: () => onRequestPurge(row),
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
    required this.onRequestPurge,
  });

  final BinRow row;
  final IconData? sectionIcon;
  final VoidCallback onRestore;
  final VoidCallback onRequestPurge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final referenceLabel = row.referenceCount == 1
        ? '1 reference'
        : '${row.referenceCount} references';

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Restore ${row.name}'): onRestore,
        CustomSemanticsAction(label: 'Purge ${row.name}'): onRequestPurge,
      },
      child: Dismissible(
        key: ValueKey('bin-${row.kind}-${row.id}'),
        direction: DismissDirection.horizontal,
        background: const _RestoreBackground(),
        secondaryBackground: const _PurgeBackground(),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onRestore();
          } else {
            onRequestPurge();
          }
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
                  : Icon(
                      sectionIcon,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
