part of '../recycle_bin_sections.dart';

// MARK: - Section Tray

class BinSectionTray extends StatelessWidget {
  const BinSectionTray({super.key, required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (final (index, row) in rows.indexed) {
      if (index > 0) spaced.add(const EdgeDivider());
      spaced.add(row);
    }
    return Tray(
      title: title,
      child: Column(children: spaced),
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
    final tiles = [
      for (final row in rows)
        SwipeableBinRow(
          row: row,
          onRestore: () => onRestore(row),
          onRequestPurge: () => onRequestPurge(row),
          child: BinEntryRowContent(row: row, onRestore: () => onRestore(row)),
        ),
    ];
    return BinSectionTray(title: _title, rows: tiles);
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
    final tiles = [
      for (final row in rows)
        BinRowTile(
          row: row,
          sectionIcon: sectionIcon,
          onRestore: () => onRestore(row),
          onRequestPurge: () => onRequestPurge(row),
        ),
    ];
    return BinSectionTray(title: title, rows: tiles);
  }
}
