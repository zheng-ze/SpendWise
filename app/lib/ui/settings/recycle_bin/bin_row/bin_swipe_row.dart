part of '../recycle_bin_sections.dart';

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
