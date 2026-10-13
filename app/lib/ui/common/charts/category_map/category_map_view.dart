part of '../category_map.dart';

// MARK: - Map

@immutable
class _AdjacentLabel {
  const _AdjacentLabel({required this.tile, required this.index});

  final CategoryMapTile tile;

  final int index;
}

class CategoryMap extends StatelessWidget {
  const CategoryMap({
    super.key,
    required this.tiles,
    this.selectedIndex,
    this.onSelect,
    this.height = _defaultHeight,
  });

  static const _defaultHeight = 136.0;

  final List<CategoryMapTile> tiles;

  final int? selectedIndex;

  final ValueChanged<int>? onSelect;

  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final scaler = MediaQuery.textScalerOf(context);
        final shares = [for (final tile in tiles) tile.share];
        final rects = layoutCategoryMap(shares, Size(width, height));
        final fits = [
          for (var i = 0; i < tiles.length; i++)
            !rects[i].isEmpty &&
                _labelFits(
                  rects[i],
                  tiles[i].label,
                  _shareText(tiles[i].share),
                  scaler,
                ),
        ];
        final blocks = [
          for (var i = 0; i < tiles.length; i++)
            if (!rects[i].isEmpty)
              Positioned.fromRect(
                rect: _paddedBlock(rects[i]),
                child: _MapBlock(
                  tile: tiles[i],
                  labelInside: fits[i],
                  selected: i == selectedIndex,
                  onTap: onSelect == null ? null : () => onSelect!(i),
                ),
              ),
        ];
        final outside = [
          for (var i = 0; i < tiles.length; i++)
            if (!rects[i].isEmpty && !fits[i])
              _AdjacentLabel(tile: tiles[i], index: i),
        ];
        final mapView = SizedBox(
          width: width,
          height: height,
          child: Stack(children: blocks),
        );
        final legend = outside.isEmpty
            ? null
            : _AdjacentLabels(
                labels: outside,
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                maxWidth: width,
              );
        final content = [mapView, ?legend];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        );
      },
    );
  }
}
