import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/charts/category_map_layout.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

export 'package:spendwise/ui/common/charts/category_map_layout.dart';

// MARK: - Constants

const _semiBoldWeight = FontWeight.w600;

const _percentFactor = 100.0;

const _emptyExtent = 0.0;

const _shareFractionDigits = 1;

const _labelInset = 20.0;

const _labelFontSize = 12.0;

const _nameMaxLines = 2;

const _shareMaxLines = 1;

const _nameShareGap = 2.0;

const _minBlockSize = 4.0;

const _blockInset = 2.0;

// MARK: - Tile

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

// MARK: - Helpers

String _shareText(double share) =>
    '${(share * _percentFactor).toStringAsFixed(_shareFractionDigits)}%';

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
  final available = Size(rect.width - _labelInset, rect.height - _labelInset);
  if (available.width <= _emptyExtent || available.height <= _emptyExtent) {
    return false;
  }
  const style = TextStyle(
    fontSize: _labelFontSize,
    fontWeight: _semiBoldWeight,
  );
  final namePainter = _measure(
    name,
    style,
    scaler,
    available.width,
    _nameMaxLines,
    '...',
  );
  if (namePainter.didExceedMaxLines) return false;
  final sharePainter = _measure(
    share,
    style,
    scaler,
    available.width,
    _shareMaxLines,
    null,
  );
  if (sharePainter.didExceedMaxLines) return false;
  return namePainter.height + _nameShareGap + sharePainter.height <=
      available.height;
}

Rect _paddedBlock(Rect rect) {
  if (rect.width <= _minBlockSize || rect.height <= _minBlockSize) return rect;
  return rect.deflate(_blockInset);
}

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

// MARK: - Adjacent Labels

class _AdjacentLabels extends StatelessWidget {
  const _AdjacentLabels({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    required this.maxWidth,
  });

  static const _topPadding = 4.0;

  static const _bottomPadding = 6.0;

  static const _labelSpacing = 12.0;

  static const _labelRunSpacing = 4.0;

  final List<_AdjacentLabel> labels;

  final int? selectedIndex;

  final ValueChanged<int>? onSelect;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _topPadding, bottom: _bottomPadding),
      child: Wrap(
        spacing: _labelSpacing,
        runSpacing: _labelRunSpacing,
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

  static const _swatchSize = 10.0;

  static const _swatchRadius = 3.0;

  static const _captionFontSize = 10.0;

  static const _captionMaxLines = 3;

  static const _swatchLabelGap = 5.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final swatch = Container(
      width: _swatchSize,
      height: _swatchSize,
      decoration: BoxDecoration(
        color: _selectionFill(selected, colors.selectedMark, label.tile.color),
        borderRadius: BorderRadius.circular(_swatchRadius),
      ),
    );
    final labelText = Text(
      '${label.tile.label} ${_shareText(label.tile.share)}',
      style: TextStyle(fontSize: _captionFontSize, color: colors.subtext),
      maxLines: _captionMaxLines,
      overflow: TextOverflow.ellipsis,
    );
    final row = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(width: _swatchLabelGap),
          Flexible(child: labelText),
        ],
      ),
    );

    return _tappable(row, onTap);
  }
}
