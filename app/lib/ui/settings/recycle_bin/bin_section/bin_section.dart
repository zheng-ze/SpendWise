part of '../recycle_bin_sections.dart';

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
