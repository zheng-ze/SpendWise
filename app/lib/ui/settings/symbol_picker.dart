import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/symbol_map.dart';

const _gridColumns = 6;

/// Returns sections whose names match [query], dropping any section left
/// with no matches rather than keeping it empty.
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

/// Returns the chosen symbol name, or null if the user backed out without
/// choosing.
Future<String?> showSymbolPickerSheet({
  required BuildContext context,
  required String selected,
  required Color color,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => SymbolPicker(selected: selected, color: color),
    ),
  );
}

class SymbolPicker extends StatefulWidget {
  const SymbolPicker({super.key, required this.selected, required this.color});

  final String selected;
  final Color color;

  @override
  State<SymbolPicker> createState() => _SymbolPickerState();
}

class _SymbolPickerState extends State<SymbolPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = filterSymbolSections(categoryIconSections, _query);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Icon')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final section in sections.entries)
                  _SymbolSection(
                    title: section.key,
                    names: section.value,
                    selected: widget.selected,
                    color: widget.color,
                    onChosen: (name) => Navigator.of(context).pop(name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridColumns,
          ),
          itemCount: names.length,
          itemBuilder: (context, index) {
            final name = names[index];
            return InkWell(
              onTap: () => onChosen(name),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CategoryIcon(
                  symbolName: name,
                  color: color,
                  selected: name == selected,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
