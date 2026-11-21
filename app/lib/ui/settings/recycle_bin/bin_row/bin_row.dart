part of '../recycle_bin_sections.dart';

// MARK: - Restore Action

class BinRestoreAction extends StatelessWidget {
  const BinRestoreAction({super.key, required this.onRestore});

  final VoidCallback onRestore;

  static const _minHeight = 30.0;
  static const _minWidth = 48.0;
  static const _fontSize = 12.0;
  static const _weight = FontWeight.w600;
  static const _label = 'Restore';

  @override
  Widget build(BuildContext context) {
    final label = Text(
      _label,
      style: TextStyle(
        fontSize: _fontSize,
        fontWeight: _weight,
        color: context.colors.action,
      ),
    );
    return ExcludeSemantics(
      child: InkWell(
        onTap: onRestore,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minWidth,
            minHeight: _minHeight,
          ),
          child: Center(child: label),
        ),
      ),
    );
  }
}

// MARK: - Entry Row

class BinEntryRowContent extends StatelessWidget {
  const BinEntryRowContent({
    super.key,
    required this.row,
    required this.onRestore,
  });

  final BinEntryRow row;
  final VoidCallback onRestore;

  static const _contentPadding = EdgeInsets.symmetric(vertical: 7);
  static const _restoreGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final amountText = AmountText(amount: row.amount, kind: row.amountKind);
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        amountText,
        const SizedBox(width: _restoreGap),
        BinRestoreAction(onRestore: onRestore),
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

  static const _medallionSize = 30.0;
  static const _contentPadding = EdgeInsets.symmetric(vertical: 7);
  static const _singleEntryLabel = 'Used by 1 entry';

  @override
  Widget build(BuildContext context) {
    final usageLabel = row.referenceCount == 1
        ? _singleEntryLabel
        : 'Used by ${row.referenceCount} entries';
    final symbolName = row.symbolName;
    final medallion = symbolName == null
        ? null
        : CategoryIcon(
            symbolName: symbolName,
            color: row.color ?? colorHexFallback,
            size: _medallionSize,
          );
    final content = Padding(
      padding: _contentPadding,
      child: MedallionRow(
        icon: medallion == null ? sectionIcon : null,
        leading: medallion,
        title: row.name,
        subtitle: usageLabel,
        trailing: BinRestoreAction(onRestore: onRestore),
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
