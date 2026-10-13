part of '../category_map.dart';

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
