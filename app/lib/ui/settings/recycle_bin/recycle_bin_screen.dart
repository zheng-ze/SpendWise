import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/medallion_row.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: context.colors.onAction,
            ),
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
    final entries = viewState.entries;
    final accounts = viewState.accounts;
    final pockets = viewState.pockets;
    final categories = viewState.categories;

    final isEmpty =
        entries.isEmpty &&
        accounts.isEmpty &&
        pockets.isEmpty &&
        categories.isEmpty;

    void restore(BinRow row) => viewModel.restore(row.kind, row.id);
    void requestPurge(BinRow row) => viewModel.requestPurge(row);

    final sections = [
      if (entries.isNotEmpty)
        _EntriesSection(
          rows: entries,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
      if (accounts.isNotEmpty)
        _BinSection(
          title: 'Accounts',
          sectionIcon: symbolIcon('wallet'),
          rows: accounts,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
      if (pockets.isNotEmpty)
        _BinSection(
          title: 'Subpockets',
          sectionIcon: symbolIcon('inbox'),
          rows: pockets,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
      if (categories.isNotEmpty)
        _BinSection(
          title: 'Categories',
          sectionIcon: null,
          rows: categories,
          onRestore: restore,
          onRequestPurge: requestPurge,
        ),
    ];
    final content = isEmpty
        ? const _EmptyState()
        : ListView(children: sections);

    return Scaffold(
      appBar: AppBar(title: const Text('Recycle bin')),
      body: SafeArea(child: content),
    );
  }
}

class _BinSectionTitle extends StatelessWidget {
  const _BinSectionTitle(this.title);

  final String title;

  static const _titlePadding = EdgeInsets.fromLTRB(16, 16, 16, 4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: _titlePadding,
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EntriesSection extends StatelessWidget {
  const _EntriesSection({
    required this.rows,
    required this.onRestore,
    required this.onRequestPurge,
  });

  final List<BinEntryRow> rows;
  final void Function(BinRow row) onRestore;
  final void Function(BinRow row) onRequestPurge;

  static const _title = 'Entries';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BinSectionTitle(_title),
        for (final row in rows)
          _SwipeableBinRow(
            row: row,
            onRestore: () => onRestore(row),
            onRequestPurge: () => onRequestPurge(row),
            child: _EntryRowContent(row: row, onRestore: () => onRestore(row)),
          ),
      ],
    );
  }
}

class _EntryRowContent extends StatelessWidget {
  const _EntryRowContent({required this.row, required this.onRestore});

  final BinEntryRow row;
  final VoidCallback onRestore;

  static const _contentPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 7,
  );
  static const _restoreGap = 6.0;
  static const _restoreFontSize = 12.0;
  static const _restoreWeight = FontWeight.w600;
  static const _restoreLabel = 'Restore';
  static const _amountFontSize = 12.0;
  static const _amountWeight = FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    final amountStyle = TextStyle(
      fontSize: _amountFontSize,
      fontWeight: _amountWeight,
      color: AmountStyle.of(context, kind: row.amountKind).color,
    );
    final amountText = formatSignedMoney(
      row.amount,
      kind: row.amountKind,
      symbol: false,
    );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(amountText, style: amountStyle),
        const SizedBox(width: _restoreGap),
        Semantics(
          button: true,
          label: _restoreLabel,
          excludeSemantics: true,
          child: InkWell(
            onTap: onRestore,
            child: Text(
              _restoreLabel,
              style: TextStyle(
                fontSize: _restoreFontSize,
                fontWeight: _restoreWeight,
                color: context.colors.action,
              ),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: _contentPadding,
      child: MedallionRow(
        icon: symbolIcon(row.symbolName!),
        iconColor: row.color,
        title: row.name,
        subtitle: row.caption,
        trailing: trailing,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BinSectionTitle(title),
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

  static const _iconSize = 28.0;
  static const _contentPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );
  static const _leadingGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final referenceLabel = row.referenceCount == 1
        ? '1 reference'
        : '${row.referenceCount} references';

    final leading = row.symbolName != null
        ? CategoryIcon(
            symbolName: row.symbolName!,
            color: row.color ?? colorHexFallback,
            size: _iconSize,
          )
        : Icon(sectionIcon, color: theme.colorScheme.onSurfaceVariant);
    final title = Expanded(
      child: Text(row.name, style: theme.textTheme.bodyLarge),
    );
    final references = Text(
      referenceLabel,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final content = Padding(
      padding: _contentPadding,
      child: Row(
        children: [
          leading,
          const SizedBox(width: _leadingGap),
          title,
          references,
        ],
      ),
    );
    return _SwipeableBinRow(
      row: row,
      onRestore: onRestore,
      onRequestPurge: onRequestPurge,
      child: content,
    );
  }
}

class _SwipeableBinRow extends StatelessWidget {
  const _SwipeableBinRow({
    required this.row,
    required this.onRestore,
    required this.onRequestPurge,
    required this.child,
  });

  final BinRow row;
  final VoidCallback onRestore;
  final VoidCallback onRequestPurge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tile = Dismissible(
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
      child: child,
    );

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Restore ${row.name}'): onRestore,
        CustomSemanticsAction(label: 'Purge ${row.name}'): onRequestPurge,
      },
      child: tile,
    );
  }
}

class _RestoreBackground extends StatelessWidget {
  const _RestoreBackground();

  static const _backgroundPadding = EdgeInsets.symmetric(horizontal: 20);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.action,
      alignment: Alignment.centerLeft,
      padding: _backgroundPadding,
      child: Icon(symbolIcon('undo'), color: context.colors.onAction),
    );
  }
}

class _PurgeBackground extends StatelessWidget {
  const _PurgeBackground();

  static const _backgroundPadding = EdgeInsets.symmetric(horizontal: 20);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: _backgroundPadding,
      child: Icon(Icons.delete_outline, color: context.colors.onAction),
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
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
