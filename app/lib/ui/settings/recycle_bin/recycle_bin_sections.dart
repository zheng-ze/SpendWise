import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/medallion_row.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Section Title

class BinSectionTitle extends StatelessWidget {
  const BinSectionTitle(this.title, {super.key});

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

// MARK: - Entries Section

class BinEntriesSection extends StatelessWidget {
  const BinEntriesSection({
    super.key,
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
        const BinSectionTitle(_title),
        for (final row in rows)
          SwipeableBinRow(
            row: row,
            onRestore: () => onRestore(row),
            onRequestPurge: () => onRequestPurge(row),
            child: BinEntryRowContent(
              row: row,
              onRestore: () => onRestore(row),
            ),
          ),
      ],
    );
  }
}

class BinEntryRowContent extends StatelessWidget {
  const BinEntryRowContent({
    super.key,
    required this.row,
    required this.onRestore,
  });

  final BinEntryRow row;
  final VoidCallback onRestore;

  static const _contentPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 7,
  );
  static const _restoreMinHeight = 30.0;
  static const _restoreMinWidth = 48.0;
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
        ExcludeSemantics(
          child: InkWell(
            onTap: onRestore,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _restoreMinWidth,
                minHeight: _restoreMinHeight,
              ),
              child: Center(
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
          ),
        ),
      ],
    );

    return Padding(
      padding: _contentPadding,
      child: MedallionRow(
        icon: symbolIcon(row.symbolName),
        iconColor: row.color,
        title: row.name,
        subtitle: row.caption,
        trailing: trailing,
      ),
    );
  }
}

// MARK: - Generic Section

class BinSection extends StatelessWidget {
  const BinSection({
    super.key,
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
        BinSectionTitle(title),
        for (final row in rows)
          BinRowTile(
            row: row,
            sectionIcon: sectionIcon,
            onRestore: () => onRestore(row),
            onRequestPurge: () => onRequestPurge(row),
          ),
      ],
    );
  }
}

class BinRowTile extends StatelessWidget {
  const BinRowTile({
    super.key,
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

  static const _singleReferenceLabel = '1 reference';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final referenceLabel = row.referenceCount == 1
        ? _singleReferenceLabel
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
    return SwipeableBinRow(
      row: row,
      onRestore: onRestore,
      onRequestPurge: onRequestPurge,
      child: content,
    );
  }
}

// MARK: - Swipeable Row

class SwipeableBinRow extends StatelessWidget {
  const SwipeableBinRow({
    super.key,
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
      background: const BinRestoreBackground(),
      secondaryBackground: const BinPurgeBackground(),
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

// MARK: - Swipe Backgrounds

class BinRestoreBackground extends StatelessWidget {
  const BinRestoreBackground({super.key});

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

class BinPurgeBackground extends StatelessWidget {
  const BinPurgeBackground({super.key});

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

// MARK: - Empty State

class BinEmptyState extends StatelessWidget {
  const BinEmptyState({super.key});

  static const _emptyTitle = 'Recycle bin is empty';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _emptyTitle,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
