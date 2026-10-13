part of '../recycle_bin_sections.dart';

// MARK: - Entry Row

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

// MARK: - Row Tile

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
