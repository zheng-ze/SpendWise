import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/lists/section_label.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _sheetTitle = 'Icon and colour';

const _doneLabel = 'Done';

const _iconSectionLabel = 'Icon';

const _colourSectionLabel = 'Colour';

const _gridColumns = 6;

const _gridSpacing = 8.0;

const _previewPadding = EdgeInsets.fromLTRB(16, 0, 16, 0);

const _previewSize = 44.0;

const _previewGap = 12.0;

const _sectionLabelPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

const _gridPadding = EdgeInsets.symmetric(horizontal: 16);

const _transparent = Color(0x00000000);

const _tileRadius = 14.0;

const _tileBorderWidth = 2.0;

const _tileGlyphSize = 24.0;

const _checkSymbol = 'check';

const _swatchesPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);

const _swatchSpacing = 12.0;

const _swatchSize = 32.0;

const _swatchEdgeWidth = 2.0;

const _swatchRingWidth = 3.0;

const _swatchRingInset = _swatchRingWidth - _swatchEdgeWidth;

const _swatchCheckSize = 20.0;

// MARK: - Result
class SymbolPickerResult {
  const SymbolPickerResult({required this.symbol, required this.color});

  final String symbol;
  final Color color;
}

// MARK: - Helpers

String symbolDisplayName(String name) {
  final words = name.replaceAll('_', ' ');
  if (words.isEmpty) return '';
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

// MARK: - Show
Future<SymbolPickerResult?> showSymbolPickerSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) presentation,
  required String symbol,
  required Color color,
  required List<Color> swatches,
  String categoryName = '',
  PickerRouteCallback? onRouteCreated,
}) {
  return showPickerAppSheet<SymbolPickerResult>(
    context,
    presentation: presentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => SymbolPicker(
      symbol: symbol,
      color: color,
      swatches: swatches,
      categoryName: categoryName,
    ),
  );
}

// MARK: - SymbolPicker
class SymbolPicker extends StatefulWidget {
  const SymbolPicker({
    super.key,
    required this.symbol,
    required this.color,
    required this.swatches,
    this.categoryName = '',
  });

  final String symbol;
  final Color color;
  final List<Color> swatches;
  final String categoryName;

  @override
  State<SymbolPicker> createState() => _SymbolPickerState();
}

// MARK: - SymbolPickerState
class _SymbolPickerState extends State<SymbolPicker> {
  late String _symbol = widget.symbol;
  late Color _color = widget.color;

  void _chooseSymbol(String name) => setState(() => _symbol = name);

  void _chooseColor(Color swatch) => setState(() => _color = swatch);

  void _done() {
    final result = SymbolPickerResult(symbol: _symbol, color: _color);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final displayColor = CategoryPalette.savedColor(
      toColorHex(_color),
      context.colors,
    );
    final done = TextButton(
      key: pickerDoneKey,
      onPressed: _done,
      child: const Text(_doneLabel),
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Preview(
          symbol: _symbol,
          color: displayColor,
          categoryName: widget.categoryName,
        ),
        const SectionLabel(_iconSectionLabel, padding: _sectionLabelPadding),
        _IconGrid(selected: _symbol, onChosen: _chooseSymbol),
        const SectionLabel(_colourSectionLabel, padding: _sectionLabelPadding),
        _SwatchRow(
          swatches: widget.swatches,
          selected: _color,
          onChosen: _chooseColor,
        ),
      ],
    );

    return AppPickerSheet(title: _sheetTitle, trailing: done, body: body);
  }
}

const _previewNameMaxLines = 1;

// MARK: - Preview
class _Preview extends StatelessWidget {
  const _Preview({
    required this.symbol,
    required this.color,
    required this.categoryName,
  });

  final String symbol;
  final Color color;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final medallion = CategoryIcon(
      symbolName: symbol,
      color: color,
      size: _previewSize,
    );
    final trimmedName = categoryName.trim();
    final label = trimmedName.isEmpty ? symbolDisplayName(symbol) : trimmedName;
    final name = Expanded(
      child: Text(
        label,
        maxLines: _previewNameMaxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Padding(
      padding: _previewPadding,
      child: Row(spacing: _previewGap, children: [medallion, name]),
    );
  }
}

// MARK: - IconGrid
class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onChosen});

  final String selected;
  final void Function(String name) onChosen;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final name in categoryIconNames)
        _IconTile(
          symbolName: name,
          selected: name == selected,
          onTap: () => onChosen(name),
        ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: _gridPadding,
      crossAxisCount: _gridColumns,
      mainAxisSpacing: _gridSpacing,
      crossAxisSpacing: _gridSpacing,
      children: tiles,
    );
  }
}

// MARK: - IconTile
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.symbolName,
    required this.selected,
    required this.onTap,
  });

  final String symbolName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_tileRadius);
    final side = BorderSide(
      color: selected ? colors.focus : _transparent,
      width: _tileBorderWidth,
    );
    final glyph = Icon(
      symbolIcon(symbolName),
      size: _tileGlyphSize,
      color: selected ? colors.action : colors.text,
    );

    return Material(
      color: colors.tint,
      shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      child: InkWell(
        key: ValueKey(symbolName),
        borderRadius: radius,
        onTap: onTap,
        child: Center(child: glyph),
      ),
    );
  }
}

// MARK: - SwatchRow
class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.swatches,
    required this.selected,
    required this.onChosen,
  });

  final List<Color> swatches;
  final Color selected;
  final ValueChanged<Color> onChosen;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final swatch in swatches)
        _Swatch(
          key: ValueKey(swatch),
          swatch: swatch,
          selected: swatch == selected,
          onTap: () => onChosen(swatch),
        ),
    ];

    return Padding(
      padding: _swatchesPadding,
      child: Wrap(
        spacing: _swatchSpacing,
        runSpacing: _swatchSpacing,
        children: chips,
      ),
    );
  }
}

// MARK: - Swatch
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final Color swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final edge = Border.all(
      color: selected ? colors.focus : _transparent,
      width: _swatchEdgeWidth,
    );
    final fill = BoxDecoration(
      shape: BoxShape.circle,
      color: CategoryPalette.savedColor(toColorHex(swatch), colors),
      border: edge,
    );
    final ring = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.base, width: _swatchRingWidth),
      ),
      child: Center(
        child: Icon(
          symbolIcon(_checkSymbol),
          size: _swatchCheckSize,
          color: colors.onCategory,
        ),
      ),
    );
    final mark = Padding(
      padding: const EdgeInsets.all(_swatchRingInset),
      child: ring,
    );
    final chip = DecoratedBox(decoration: fill, child: selected ? mark : null);

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: _swatchSize, height: _swatchSize, child: chip),
    );
  }
}
