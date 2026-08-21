import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/settings/category_form_logic.dart';
import 'package:spendwise/ui/settings/symbol_picker.dart';

const _defaultColor = Color(0xFF007AFF);

const _swatches = [
  _defaultColor,
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF5AC8FA),
  Color(0xFFAF52DE),
  Color(0xFF8E8E93),
];

Future<void> showCategoryFormSheet({
  required BuildContext context,
  required Ledger ledger,
  TransactionCategory? category,
  String? presetParentID,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CategoryForm(
      ledger: ledger,
      category: category,
      presetParentID: presetParentID,
    ),
  );
}

class CategoryForm extends StatefulWidget {
  const CategoryForm({
    super.key,
    required this.ledger,
    this.category,
    this.presetParentID,
  });

  final Ledger ledger;
  final TransactionCategory? category;
  final String? presetParentID;

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );

  late CategoryKind _kind =
      widget.category?.kind ?? _presetParent?.kind ?? CategoryKind.expense;
  late String _symbol = widget.category?.symbol ?? 'tag';
  late Color _color = _initialColor();
  late bool _includeInAnalysis = widget.category?.includeInAnalysis ?? true;
  late String? _parentID = widget.category?.parentID ?? widget.presetParentID;

  LedgerError? _error;

  TransactionCategory? get _presetParent {
    final id = widget.presetParentID;
    if (id == null) return null;
    return widget.ledger.state.categories[id];
  }

  Color _initialColor() {
    final ownHex = widget.category?.colorHex;
    if (ownHex != null) return parseColorHex(ownHex);
    final parentHex = _presetParent?.colorHex;
    return parentHex != null ? parseColorHex(parentHex) : _defaultColor;
  }

  bool get _isEditing => widget.category != null;

  bool get _hasPresetParent => widget.presetParentID != null;

  bool get _isReferenced =>
      _isEditing &&
      widget.ledger.state.entryCountReferencing(widget.category!.id) > 0;

  bool get _kindLocked => isKindLocked(
    hasPresetParent: _hasPresetParent,
    isReferenced: _isReferenced,
  );

  List<TransactionCategory> get _eligibleParents => eligibleParents(
    widget.ledger.state.categories.values.toList(),
    _kind,
    excludingID: widget.category?.id,
  );

  bool get _showParentPicker =>
      !_hasPresetParent && _eligibleParents.isNotEmpty;

  bool get _canSave => canSaveCategoryForm(_nameController.text);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _setKind(CategoryKind kind) {
    setState(() {
      _kind = kind;
      final parentID = _parentID;
      if (parentID != null) {
        final parent = widget.ledger.state.categories[parentID];
        if (parent == null || parent.kind != kind) _parentID = null;
      }
    });
  }

  Future<void> _pickSymbol() async {
    final chosen = await showSymbolPickerSheet(
      context: context,
      selected: _symbol,
      color: _color,
    );
    if (chosen != null && mounted) setState(() => _symbol = chosen);
  }

  Future<void> _pickParent() async {
    final options = _eligibleParents;
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('None'),
              onTap: () => Navigator.of(context).pop(),
            ),
            for (final option in options)
              ListTile(
                title: Text(option.name),
                onTap: () => Navigator.of(context).pop(option.id),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _parentID = chosen);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    try {
      final category = TransactionCategory(
        id: widget.category?.id,
        name: name,
        kind: _kind,
        colorHex: toColorHex(_color),
        includeInAnalysis: _includeInAnalysis,
        parentID: _parentID,
        symbol: _symbol,
        lifecycle: widget.category?.lifecycle ?? LifecycleState.active,
      );

      if (_isEditing) {
        widget.ledger.updateCategory(category);
      } else {
        widget.ledger.addCategory(category);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on LedgerError catch (error) {
      setState(() => _error = error);
    }
  }

  void _delete() {
    widget.ledger.deleteCategory(widget.category!.id);
    Navigator.of(context).pop();
  }

  String get _title {
    if (_isEditing) return 'Edit Category';
    if (_hasPresetParent) return 'New Subcategory';
    return 'New Category';
  }

  String? get _parentLabel {
    final id = _parentID;
    if (id == null) return null;
    return widget.ledger.state.categories[id]?.name;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: _title,
      canSave: _canSave,
      onSave: _save,
      error: ErrorSection(subject: 'category', error: _error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: _kindLocked,
            child: Opacity(
              opacity: _kindLocked ? 0.5 : 1,
              child: SegmentedButton<CategoryKind>(
                segments: const [
                  ButtonSegment(
                    value: CategoryKind.income,
                    label: Text('Income'),
                  ),
                  ButtonSegment(
                    value: CategoryKind.expense,
                    label: Text('Expense'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _kindLocked
                    ? null
                    : (selection) => _setKind(selection.first),
              ),
            ),
          ),
          if (_kindLocked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Type is locked while transactions use this category.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Symbol'),
            leading: CategoryIcon(symbolName: _symbol, color: _color),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickSymbol,
          ),
          const SizedBox(height: 16),
          Text('Color', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final swatch in _swatches)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = swatch),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: swatch,
                      border: swatch == _color
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include in analysis'),
            value: _includeInAnalysis,
            onChanged: (value) => setState(() => _includeInAnalysis = value),
          ),
          if (_showParentPicker)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Parent'),
              trailing: Text(_parentLabel ?? 'None'),
              onTap: _pickParent,
            ),
          if (_isEditing) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _delete,
                child: const Text('Delete Category'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
