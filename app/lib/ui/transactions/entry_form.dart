import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/category_icon.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/common/two_column_picker_sheet.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/category_picker.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/recurrence_picker.dart';
import 'package:spendwise/ui/transactions/source_picker.dart';

enum _FormMode { newEntry, viewing, editing }

const _frequencyLabels = <RecurrenceFrequency, String>{
  RecurrenceFrequency.weekly: 'Weekly',
  RecurrenceFrequency.biweekly: 'Biweekly',
  RecurrenceFrequency.monthly: 'Monthly',
  RecurrenceFrequency.quarterly: 'Quarterly',
  RecurrenceFrequency.yearly: 'Yearly',
};

/// Opens the entry form as a near-full-height sheet. Pass [entry] to open an
/// existing one read-only, or omit it for a new entry. [sourceScope]
/// prefills the source when opened from an account-scoped screen.
Future<void> showEntryFormSheet({
  required BuildContext context,
  required Ledger ledger,
  Entry? entry,
  String? sourceScope,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.95,
      child: EntryForm(ledger: ledger, entry: entry, sourceScope: sourceScope),
    ),
  );
}

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    required this.ledger,
    this.entry,
    this.sourceScope,
  });

  final Ledger ledger;
  final Entry? entry;
  final String? sourceScope;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late _FormMode _mode = widget.entry == null
      ? _FormMode.newEntry
      : _FormMode.viewing;

  late EntryFormKind _kind = _kindOf(widget.entry);
  late final TextEditingController _amountController = TextEditingController(
    text: widget.entry == null
        ? ''
        : formatPlainAmount(widget.entry!.amount.abs()),
  );
  late final TextEditingController _nameController = TextEditingController(
    text: widget.entry?.name ?? '',
  );
  late DateTime _date = widget.entry?.date ?? _todayUtc();
  late String? _sourceId = widget.entry?.sourceID ?? widget.sourceScope;
  late String? _destinationId = widget.entry?.destinationID;
  late String? _categoryId = widget.entry?.categoryID;
  late bool _includeInAnalysis = widget.entry?.includeInAnalysis ?? true;

  RecurrenceFrequency? _recurrence;
  bool _hasEndDate = false;
  DateTime? _endDate;

  LedgerError? _error;

  bool get _isSystemEntry => widget.entry?.systemKind != null;

  static DateTime _todayUtc() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  static EntryFormKind _kindOf(Entry? entry) {
    if (entry == null) return EntryFormKind.expense;
    if (entry.isTransfer) return EntryFormKind.transfer;
    return entry.amount < Decimal.zero
        ? EntryFormKind.expense
        : EntryFormKind.income;
  }

  Decimal? get _parsedAmount => Decimal.tryParse(_amountController.text);

  bool get _canSave => canSaveEntryForm(
    amount: _parsedAmount,
    name: _nameController.text,
    sourceId: _sourceId,
    kind: _kind,
    destinationId: _destinationId,
  );

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _revertToPersisted() {
    final entry = widget.entry!;
    setState(() {
      _kind = _kindOf(entry);
      _amountController.text = formatPlainAmount(entry.amount.abs());
      _nameController.text = entry.name;
      _date = entry.date;
      _sourceId = entry.sourceID;
      _destinationId = entry.destinationID;
      _categoryId = entry.categoryID;
      _includeInAnalysis = entry.includeInAnalysis;
      _error = null;
      _mode = _FormMode.viewing;
    });
  }

  void _setKind(EntryFormKind kind) {
    setState(() {
      _kind = kind;
      _categoryId = null;
      if (kind != EntryFormKind.transfer) _destinationId = null;
    });
  }

  void _applyPickerOutcome(
    PickerOutcome? outcome,
    ValueSetter<String?> assign,
  ) {
    if (outcome == null) return;
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case PickerChose(:final id):
          assign(id);
        case PickerCleared():
          assign(null);
      }
    });
  }

  Future<void> _pickSource() async {
    final outcome = await showSourcePickerSheet(
      context: context,
      title: _kind == EntryFormKind.transfer ? 'From' : 'Account',
      state: widget.ledger.state,
      selectedId: _sourceId,
    );
    _applyPickerOutcome(outcome, (id) => _sourceId = id);
  }

  Future<void> _pickDestination() async {
    final outcome = await showSourcePickerSheet(
      context: context,
      title: 'To',
      state: widget.ledger.state,
      selectedId: _destinationId,
    );
    _applyPickerOutcome(outcome, (id) => _destinationId = id);
  }

  Future<void> _pickCategory() async {
    final categoryKind = _kind == EntryFormKind.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final outcome = await showCategoryPickerSheet(
      context: context,
      state: widget.ledger.state,
      kind: categoryKind,
      selectedId: _categoryId,
    );
    _applyPickerOutcome(outcome, (id) => _categoryId = id);
  }

  Future<void> _pickRecurrence() async {
    final chosen = await showRecurrencePickerSheet(
      context: context,
      selected: _recurrence,
    );
    if (!mounted) return;
    setState(() {
      _recurrence = chosen;
      if (chosen == null) {
        _hasEndDate = false;
        _endDate = null;
      }
    });
  }

  Future<DateTime?> _pickNormalizedDate({
    required DateTime initial,
    required DateTime first,
    DateTime? last,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last ?? DateTime.utc(2100),
    );
    if (picked == null) return null;
    return DateTime.utc(picked.year, picked.month, picked.day);
  }

  Future<void> _pickDate() async {
    final picked = await _pickNormalizedDate(
      initial: _date,
      first: DateTime.utc(2000),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _date = picked;
      if (_endDate != null && _endDate!.isBefore(_date)) {
        _endDate = _date;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickNormalizedDate(
      initial: _endDate ?? _date,
      first: _date,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    final magnitude = _parsedAmount!.abs();
    final entry = signedEntryForSave(
      kind: _kind,
      magnitude: magnitude,
      id: widget.entry?.id,
      date: _date,
      name: _nameController.text.trim(),
      categoryId: _categoryId,
      sourceId: _sourceId!,
      destinationId: _destinationId,
      includeInAnalysis: _includeInAnalysis,
    );

    try {
      if (_mode == _FormMode.editing) {
        widget.ledger.updateEntry(entry);
        setState(() {
          _error = null;
          _mode = _FormMode.viewing;
        });
        return;
      }

      final recurrence = _recurrence;
      if (recurrence == null) {
        widget.ledger.addEntry(entry);
      } else {
        final template = EntryTemplate(
          amount: entry.amount,
          name: entry.name,
          categoryID: entry.categoryID,
          sourceID: entry.sourceID,
          destinationID: entry.destinationID,
          includeInAnalysis: entry.includeInAnalysis,
        );
        final plan = buildRecurringPlanForNewEntry(
          template: template,
          frequency: recurrence,
          anchor: _date,
          endDate: _hasEndDate ? _endDate : null,
        );
        widget.ledger.addPlan(plan);
        widget.ledger.resolvePlans(DateTime.now().toUtc());
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on LedgerError catch (error) {
      setState(() => _error = error);
    }
  }

  void _delete() {
    widget.ledger.deleteEntry(widget.entry!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _FormMode.viewing) return _buildViewing(context);
    return _buildEditable(context);
  }

  Widget _buildViewing(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Entry'),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(Icons.chevron_left),
        ),
        leadingWidth: 56,
        actions: [
          TextButton(
            onPressed: () => setState(() => _mode = _FormMode.editing),
            child: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(child: _fieldsList(readOnly: true)),
    );
  }

  Widget _buildEditable(BuildContext context) {
    final scaffold = FormScaffold(
      title: _mode == _FormMode.editing ? 'Edit Entry' : 'New Entry',
      canSave: _canSave,
      onSave: _save,
      child: _fieldsList(readOnly: false),
    );

    // Editing an existing entry reverts instead of dismissing, so its Cancel
    // has to intercept the pop FormScaffold would otherwise perform.
    if (_mode != _FormMode.editing) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _revertToPersisted();
      },
      child: scaffold,
    );
  }

  Widget _fieldsList({required bool readOnly}) {
    final isNew = _mode == _FormMode.newEntry;
    final isEditingExisting = _mode == _FormMode.editing;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _kindSelector(readOnly),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: readOnly,
          child: AmountField(
            controller: _amountController,
            allowsNegative: false,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: readOnly || _isSystemEntry,
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        _dateRow(readOnly: readOnly, isNew: isNew),
        if (isNew && _recurrence != null) ..._recurrenceSection(),
        ..._sourceDestinationRows(readOnly),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include in Analysis'),
          value: _includeInAnalysis,
          onChanged: readOnly || _isSystemEntry
              ? null
              : (value) => setState(() => _includeInAnalysis = value),
        ),
        ErrorSection(subject: 'entry', error: _error),
        if (isEditingExisting) _deleteButton(context),
      ],
    );
  }

  Widget _kindSelector(bool readOnly) {
    return IgnorePointer(
      ignoring: readOnly,
      child: SegmentedButton<EntryFormKind>(
        segments: const [
          ButtonSegment(value: EntryFormKind.expense, label: Text('Expense')),
          ButtonSegment(value: EntryFormKind.income, label: Text('Income')),
          ButtonSegment(value: EntryFormKind.transfer, label: Text('Transfer')),
        ],
        selected: {_kind},
        onSelectionChanged: readOnly
            ? null
            : (selection) => _setKind(selection.first),
      ),
    );
  }

  Widget _dateRow({required bool readOnly, required bool isNew}) {
    return Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            trailing: Text(formatEntryDate(_date)),
            onTap: readOnly ? null : _pickDate,
          ),
        ),
        if (isNew)
          IconButton(
            onPressed: _pickRecurrence,
            icon: Icon(
              Icons.repeat,
              color: _recurrence == null
                  ? null
                  : Theme.of(context).colorScheme.primary,
            ),
            tooltip: _recurrence == null
                ? 'Repeat'
                : _frequencyLabels[_recurrence!],
          ),
      ],
    );
  }

  List<Widget> _recurrenceSection() {
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ends'),
        value: _hasEndDate,
        onChanged: (value) => setState(() {
          _hasEndDate = value;
          if (value) _endDate ??= _date;
        }),
      ),
      if (_hasEndDate)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End date'),
          trailing: Text(formatEntryDate(_endDate ?? _date)),
          onTap: _pickEndDate,
        ),
    ];
  }

  List<Widget> _sourceDestinationRows(bool readOnly) {
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_kind == EntryFormKind.transfer ? 'From' : 'Account'),
        trailing: Text(_sourceLabel(_sourceId) ?? 'Select'),
        onTap: readOnly ? null : _pickSource,
      ),
      if (_kind == EntryFormKind.transfer)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('To'),
          trailing: Text(_sourceLabel(_destinationId) ?? 'Select'),
          onTap: readOnly ? null : _pickDestination,
        )
      else
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _categoryLeading(),
          title: const Text('Category'),
          trailing: Text(_categoryLabel(_categoryId) ?? 'None'),
          onTap: readOnly || _isSystemEntry ? null : _pickCategory,
        ),
    ];
  }

  Widget _deleteButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _delete,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete Entry'),
        ),
      ),
    );
  }

  Widget? _categoryLeading() {
    final id = _categoryId;
    if (id == null) return null;
    final category = widget.ledger.state.categories[id];
    if (category == null) return null;
    return CategoryIcon(
      symbolName: category.symbol,
      color: parseColorHex(category.colorHex),
      size: 24,
    );
  }

  String? _sourceLabel(String? id) => widget.ledger.state.sourceName(id);

  String? _categoryLabel(String? id) {
    if (id == null) return null;
    final category = widget.ledger.state.categories[id];
    if (category == null) return null;
    final parentID = category.parentID;
    if (parentID == null) return category.name;
    final parent = widget.ledger.state.categories[parentID];
    return parent == null ? category.name : '${parent.name}/${category.name}';
  }
}
