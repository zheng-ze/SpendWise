part of '../category_map.dart';

// MARK: - Block

class _MapBlock extends StatelessWidget {
  const _MapBlock({
    required this.tile,
    required this.labelInside,
    required this.selected,
    required this.onTap,
  });

  final CategoryMapTile tile;

  final bool labelInside;

  final bool selected;

  final VoidCallback? onTap;

  static const _blockRadius = 8.0;

  static const _blockPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = _selectionFill(selected, colors.selectedMark, tile.color);
    final label = labelInside ? _MapLabel(tile: tile, fill: fill) : null;
    final body = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_blockRadius),
      ),
      padding: const EdgeInsets.all(_blockPadding),
      child: label,
    );

    return _tappable(body, onTap);
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.tile, required this.fill});

  static const _labelMaxLines = 3;

  final CategoryMapTile tile;

  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${tile.label}\n${_shareText(tile.share)}',
      style: _blockLabelStyle(context).copyWith(color: foregroundOn(fill)),
      maxLines: _labelMaxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
