import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/lists/category_icon.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/category_palette.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _sheetTitle = 'Icon and colour';

const _doneLabel = 'Done';

const _searchHint = 'Search';

const _iconSectionLabel = 'Icon';

const _colourSectionLabel = 'Colour';

const _gridColumns = 6;

const _searchPadding = EdgeInsets.fromLTRB(16, 0, 16, 8);

const _sectionLabelPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);

const _gridPadding = EdgeInsets.symmetric(horizontal: 16);

const _cellPadding = EdgeInsets.all(4);

const _swatchesPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);

const _swatchSpacing = 12.0;

const _swatchSize = 26.0;

const _swatchRadius = 8.0;

const _selectedSwatchBorderWidth = 2.0;

// MARK: - Result
class SymbolPickerResult {
  const SymbolPickerResult({required this.symbol, required this.color});

  final String symbol;
  final Color color;
}

// MARK: - Helpers

Map<String, List<String>> filterSymbolSections(
  Map<String, List<String>> sections,
  String query,
) {
  final term = query.trim().toLowerCase();
  if (term.isEmpty) return sections;

  final result = <String, List<String>>{};
  for (final entry in sections.entries) {
    final matches = entry.value
        .where((name) => name.toLowerCase().contains(term))
        .toList();
    if (matches.isNotEmpty) result[entry.key] = matches;
  }
  return result;
}

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
  PickerRouteCallback? onRouteCreated,
}) {
  return showPickerAppSheet<SymbolPickerResult>(
    context,
    presentation: presentation,
    onRouteCreated: onRouteCreated,
    builder: (_) =>
        SymbolPicker(symbol: symbol, color: color, swatches: swatches),
  );
}

// MARK: - SymbolPicker
class SymbolPicker extends StatefulWidget {
  const SymbolPicker({
    super.key,
    required this.symbol,
    required this.color,
    required this.swatches,
  });

  final String symbol;
  final Color color;
  final List<Color> swatches;

  @override
  State<SymbolPicker> createState() => _SymbolPickerState();
}

// MARK: - SymbolPickerState
class _SymbolPickerState extends State<SymbolPicker> {
  final _searchController = TextEditingController();
  late String _symbol = widget.symbol;
  late Color _color = widget.color;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _done() {
    final result = SymbolPickerResult(symbol: _symbol, color: _color);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final sections = filterSymbolSections(categoryIconSections, _query);
    final displayColor = CategoryPalette.savedColor(
      toColorHex(_color),
      context.colors,
    );
    final done = TextButton(
      key: pickerDoneKey,
      onPressed: _done,
      child: const Text(_doneLabel),
    );
    final search = Padding(
      padding: _searchPadding,
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: _searchHint,
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        search,
        const _SectionLabel(label: _iconSectionLabel),
        for (final section in sections.entries)
          _SymbolSection(
            title: section.key,
            names: section.value,
            selected: _symbol,
            color: displayColor,
            onChosen: (name) => setState(() => _symbol = name),
          ),
        const _SectionLabel(label: _colourSectionLabel),
        _SwatchRow(
          swatches: widget.swatches,
          selected: _color,
          onChosen: (swatch) => setState(() => _color = swatch),
        ),
      ],
    );

    return AppPickerSheet(title: _sheetTitle, trailing: done, body: body);
  }
}

// MARK: - SectionLabel
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: _sectionLabelPadding,
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// MARK: - SymbolSection
class _SymbolSection extends StatelessWidget {
  const _SymbolSection({
    required this.title,
    required this.names,
    required this.selected,
    required this.color,
    required this.onChosen,
  });

  final String title;
  final List<String> names;
  final String selected;
  final Color color;
  final void Function(String name) onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: _sectionLabelPadding,
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: _gridPadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridColumns,
      ),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        return InkWell(
          onTap: () => onChosen(name),
          child: Padding(
            padding: _cellPadding,
            child: CategoryIcon(
              symbolName: name,
              color: color,
              selected: name == selected,
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, grid],
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
    final colors = context.colors;
    final borderColor = colors.text;
    final radius = BorderRadius.circular(_swatchRadius);
    final chips = [
      for (final swatch in swatches)
        InkWell(
          key: ValueKey(swatch),
          borderRadius: radius,
          onTap: () => onChosen(swatch),
          child: Container(
            width: _swatchSize,
            height: _swatchSize,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: CategoryPalette.savedColor(toColorHex(swatch), colors),
              border: swatch == selected
                  ? Border.all(
                      color: borderColor,
                      width: _selectedSwatchBorderWidth,
                    )
                  : null,
            ),
          ),
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
