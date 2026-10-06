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
    if (remaining.width < remaining.height) {
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

Color _selectionFill(bool selected, Color mark, Color fallback) =>
    selected ? mark : fallback;

Widget _tappable(Widget child, VoidCallback? onTap) {
  if (onTap == null) return child;
  return GestureDetector(onTap: onTap, child: child);
}

TextPainter _measure(
  String text,
  TextStyle style,
  TextScaler scaler,
  double maxWidth,
  int maxLines,
  String? ellipsis,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: maxLines,
    ellipsis: ellipsis,
  )..layout(maxWidth: maxWidth);
  return painter;
}

bool _labelFits(Rect rect, String name, String share, TextScaler scaler) {
  final available = Size(rect.width - 20, rect.height - 20);
  if (available.width <= 0 || available.height <= 0) return false;
  const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  final namePainter = _measure(name, style, scaler, available.width, 2, '...');
  if (namePainter.didExceedMaxLines) return false;
  final sharePainter = _measure(share, style, scaler, available.width, 1, null);
  if (sharePainter.didExceedMaxLines) return false;
  return namePainter.height + 2 + sharePainter.height <= available.height;
}

Rect _paddedBlock(Rect rect) {
  if (rect.width <= 4 || rect.height <= 4) return rect;
  return rect.deflate(2);
}

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
    final label = labelInside ? _MapLabel(tile: tile) : null;
    final body = Container(
      decoration: BoxDecoration(
        color: _selectionFill(selected, colors.selectedMark, tile.color),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: label,
    );

    return _tappable(body, onTap);
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.tile});

  final CategoryMapTile tile;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${tile.label}\n${_shareText(tile.share)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.colors.onCategory,
        height: 1.2,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _AdjacentLabels extends StatelessWidget {
  const _AdjacentLabels({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    required this.maxWidth,
  });

  final List<_AdjacentLabel> labels;

  final int? selectedIndex;

  final ValueChanged<int>? onSelect;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final label in labels)
            _AdjacentLabelRow(
              label: label,
              selected: label.index == selectedIndex,
              onTap: onSelect == null ? null : () => onSelect!(label.index),
              maxWidth: maxWidth,
            ),
        ],
      ),
    );
  }
}

class _AdjacentLabelRow extends StatelessWidget {
  const _AdjacentLabelRow({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.maxWidth,
  });

  final _AdjacentLabel label;

  final bool selected;

  final VoidCallback? onTap;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final swatch = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _selectionFill(selected, colors.selectedMark, label.tile.color),
        borderRadius: BorderRadius.circular(3),
      ),
    );
    final labelText = Text(
      '${label.tile.label} ${_shareText(label.tile.share)}',
      style: TextStyle(fontSize: 10, color: colors.subtext),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
    final row = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(width: 5),
          Flexible(child: labelText),
        ],
      ),
    );

    return _tappable(row, onTap);
  }
}
