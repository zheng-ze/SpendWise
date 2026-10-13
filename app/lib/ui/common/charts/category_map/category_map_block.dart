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
    final label = labelInside ? _MapLabel(tile: tile) : null;
    final body = Container(
      decoration: BoxDecoration(
        color: _selectionFill(selected, colors.selectedMark, tile.color),
        borderRadius: BorderRadius.circular(_blockRadius),
      ),
      padding: const EdgeInsets.all(_blockPadding),
      child: label,
    );

    return _tappable(body, onTap);
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.tile});

  static const _labelMaxLines = 3;

  static const _labelLineHeight = 1.2;

  final CategoryMapTile tile;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${tile.label}\n${_shareText(tile.share)}',
      style: TextStyle(
        fontSize: _labelFontSize,
        fontWeight: _semiBoldWeight,
        color: context.colors.onCategory,
        height: _labelLineHeight,
      ),
      maxLines: _labelMaxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
