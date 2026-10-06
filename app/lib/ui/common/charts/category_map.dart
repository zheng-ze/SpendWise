import 'package:flutter/material.dart';

import 'package:spendwise/ui/theme/spendwise_text.dart';

@immutable
class CategoryMapTile {
  const CategoryMapTile({
    required this.label,
    required this.share,
    required this.color,
  });

  final String label;

  final double share;

  final Color color;
}

List<Rect> layoutCategoryMap(List<double> values, Size size) {
  final rects = List<Rect>.filled(values.length, Rect.zero);
  if (values.isEmpty || size.width <= 0 || size.height <= 0) return rects;
  final total = values.fold<double>(0, (sum, value) => sum + value);
  if (total <= 0) return rects;
  final scale = size.width * size.height / total;
  final order = List<int>.generate(values.length, (i) => i)
    ..sort((a, b) => values[b].compareTo(values[a]));

  var remaining = Rect.fromLTWH(0, 0, size.width, size.height);
  var row = <int>[];
  var rowArea = 0.0;

  double worstOf(List<int> candidate, double area) {
    final side = remaining.width < remaining.height
        ? remaining.width
        : remaining.height;
    final thickness = area / side;
    var worst = 0.0;
    for (final i in candidate) {
      final length = values[i] * scale / thickness;
      final ratio = thickness > length
          ? thickness / length
          : length / thickness;
      if (ratio > worst) worst = ratio;
    }
    return worst;
  }

  void layoutRow() {
    if (row.isEmpty) return;
    if (remaining.width >= remaining.height) {
      final stripHeight = rowArea / remaining.width;
      var x = remaining.left;
      for (final i in row) {
        final width = values[i] * scale / stripHeight;
        rects[i] = Rect.fromLTWH(x, remaining.top, width, stripHeight);
        x += width;
      }
      remaining = Rect.fromLTWH(
        remaining.left,
        remaining.top + stripHeight,
        remaining.width,
        remaining.height - stripHeight,
      );
    } else {
      final stripWidth = rowArea / remaining.height;
      var y = remaining.top;
      for (final i in row) {
        final height = values[i] * scale / stripWidth;
        rects[i] = Rect.fromLTWH(remaining.left, y, stripWidth, height);
        y += height;
      }
      remaining = Rect.fromLTWH(
        remaining.left + stripWidth,
        remaining.top,
        remaining.width - stripWidth,
        remaining.height,
      );
    }
    row = [];
    rowArea = 0;
  }

  for (final i in order) {
    if (values[i] <= 0) {
      rects[i] = Rect.zero;
      continue;
    }
    final area = values[i] * scale;
    if (row.isEmpty) {
      row = [i];
      rowArea = area;
    } else if (worstOf([...row, i], rowArea + area) <= worstOf(row, rowArea)) {
      row.add(i);
      rowArea += area;
    } else {
      layoutRow();
      row = [i];
      rowArea = area;
    }
  }
  layoutRow();
  return rects;
}

String _shareText(double share) => '${(share * 100).toStringAsFixed(1)}%';

class CategoryMap extends StatelessWidget {
  const CategoryMap({
    super.key,
    required this.tiles,
    this.selectedIndex,
    this.onSelect,
    this.height = 136,
  });

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
        final rects = layoutCategoryMap([
          for (final tile in tiles) tile.share,
        ], Size(width, height));
        final labelled = <int>{};
        final blocks = <Widget>[];
        for (var i = 0; i < tiles.length; i++) {
          final rect = rects[i];
          if (rect.isEmpty) continue;
          final fits = rect.width >= 64 && rect.height >= 44;
          if (fits) labelled.add(i);
          blocks.add(
            Positioned.fromRect(
              rect: rect.deflate(2),
              child: _MapBlock(
                tile: tiles[i],
                labelInside: fits,
                selected: i == selectedIndex,
                onTap: onSelect == null ? null : () => onSelect!(i),
              ),
            ),
          );
        }
        final outside = [
          for (var i = 0; i < tiles.length; i++)
            if (!rects[i].isEmpty && !labelled.contains(i)) tiles[i],
        ];
        final legend = outside.isEmpty ? null : _AdjacentLabels(tiles: outside);
        final content = <Widget>[
          SizedBox(
            width: width,
            height: height,
            child: Stack(children: blocks),
          ),
        ];
        if (legend != null) content.add(legend);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        );
      },
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = Container(
      decoration: BoxDecoration(
        color: selected ? colors.selectedMark : tile.color,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: labelInside
          ? Text(
              '${tile.label}\n${_shareText(tile.share)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onCategory,
                height: 1.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
          : null,
    );
    final onTap = this.onTap;
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

class _AdjacentLabels extends StatelessWidget {
  const _AdjacentLabels({required this.tiles});

  final List<CategoryMapTile> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final tile in tiles)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tile.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${tile.label} ${_shareText(tile.share)}',
                  style: TextStyle(fontSize: 10, color: colors.subtext),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
