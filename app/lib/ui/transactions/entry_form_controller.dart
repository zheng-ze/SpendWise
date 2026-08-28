import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/category_picker.dart';
import 'package:spendwise/ui/common/recurrence_picker.dart';
import 'package:spendwise/ui/common/source_picker.dart';
import 'package:spendwise/ui/common/two_column_picker_sheet.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/entry_form_logic.dart';

enum EntryFormMode { newEntry, viewing, editing }

/// Owns an entry form's mutable state (mode, fields, controllers) and the
/// mutations that touch it. Notifies listeners on every change so the split
/// view/edit/new widgets can rebuild without reaching into a Flutter [State].
class EntryFormController extends ChangeNotifier {
  EntryFormController({
    required this.ledger,
    this.entry,
    String? sourceScope,
    String? initialName,
    Decimal? initialAmount,
    DateTime? initialDate,
  }) : mode = entry == null ? EntryFormMode.newEntry : EntryFormMode.viewing,
       kind = _kindOf(entry),
       amountController = TextEditingController(
         text: entry != null
             ? formatPlainAmount(entry.amount.abs())
             : (initialAmount == null ? '' : formatPlainAmount(initialAmount)),
       ),
       nameController = TextEditingController(
         text: entry?.name ?? initialName ?? '',
       ),
       date = entry?.date ?? initialDate ?? _todayUtc(),
       sourceId = entry?.sourceID ?? sourceScope,
       destinationId = entry?.destinationID,
       categoryId = entry?.categoryID,
       includeInAnalysis = entry?.includeInAnalysis ?? true;

  final Ledger ledger;
  final Entry? entry;

  EntryFormMode mode;
  EntryFormKind kind;
  final TextEditingController amountController;
  final TextEditingController nameController;
  DateTime date;
  String? sourceId;
  String? destinationId;
  String? categoryId;
  bool includeInAnalysis;

  RecurrenceFrequency? recurrence;
  bool hasEndDate = false;
  DateTime? endDate;

  LedgerError? error;

  bool _disposed = false;

  bool get isSystemEntry => entry?.systemKind != null;

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

  Decimal? get parsedAmount => parseAmountInput(amountController.text);

  bool get canSave => canSaveEntryForm(
    amount: parsedAmount,
    name: nameController.text,
    sourceId: sourceId,
    kind: kind,
    destinationId: destinationId,
  );

  @override
  void dispose() {
    _disposed = true;
    amountController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void startEditing() {
    mode = EntryFormMode.editing;
    notifyListeners();
  }

  void revertToPersisted() {
    final persisted = entry!;
    kind = _kindOf(persisted);
    amountController.text = formatPlainAmount(persisted.amount.abs());
    nameController.text = persisted.name;
    date = persisted.date;
    sourceId = persisted.sourceID;
    destinationId = persisted.destinationID;
    categoryId = persisted.categoryID;
    includeInAnalysis = persisted.includeInAnalysis;
    error = null;
    mode = EntryFormMode.viewing;
    notifyListeners();
  }

  void setKind(EntryFormKind newKind) {
    kind = newKind;
    categoryId = null;
    if (newKind != EntryFormKind.transfer) destinationId = null;
    notifyListeners();
  }

  void setIncludeInAnalysis(bool value) {
    includeInAnalysis = value;
    notifyListeners();
  }

  /// Called after every keystroke in the amount/name fields, since Save's
  /// enabled state depends on their live text.
  void refresh() => notifyListeners();

  /// Fills the amount/name/date fields from a receipt scan. A null [name] or
  /// [amount] leaves that field as it was rather than clearing it.
  void applyScanResult({
    String? name,
    Decimal? amount,
    required DateTime date,
  }) {
    if (_disposed) return;
    if (name != null) nameController.text = name;
    if (amount != null) amountController.text = formatPlainAmount(amount);
    this.date = date;
    notifyListeners();
  }

  void _applyPickerOutcome(
    PickerOutcome? outcome,
    ValueSetter<String?> assign,
  ) {
    if (outcome == null || _disposed) return;
    switch (outcome) {
      case PickerChose(:final id):
        assign(id);
      case PickerCleared():
        assign(null);
    }
    notifyListeners();
  }

  Future<void> pickSource(BuildContext context) async {
    final outcome = await showSourcePickerSheet(
      context: context,
      title: kind == EntryFormKind.transfer ? 'From' : 'Account',
      state: ledger.state,
      selectedId: sourceId,
    );
    _applyPickerOutcome(outcome, (id) => sourceId = id);
  }

  Future<void> pickDestination(BuildContext context) async {
    final outcome = await showSourcePickerSheet(
      context: context,
      title: 'To',
      state: ledger.state,
      selectedId: destinationId,
    );
    _applyPickerOutcome(outcome, (id) => destinationId = id);
  }

  Future<void> pickCategory(BuildContext context) async {
    final categoryKind = kind == EntryFormKind.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final outcome = await showCategoryPickerSheet(
      context: context,
      state: ledger.state,
      kind: categoryKind,
      selectedId: categoryId,
    );
    _applyPickerOutcome(outcome, (id) => categoryId = id);
  }

  Future<void> pickRecurrence(BuildContext context) async {
    final chosen = await showRecurrencePickerSheet(
      context: context,
      selected: recurrence,
    );
    if (_disposed) return;
    recurrence = chosen;
    if (chosen == null) {
      hasEndDate = false;
      endDate = null;
    }
    notifyListeners();
  }

  Future<DateTime?> _pickNormalizedDate(
    BuildContext context, {
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

  Future<void> pickDate(BuildContext context) async {
    final picked = await _pickNormalizedDate(
      context,
      initial: date,
      first: DateTime.utc(2000),
    );
    if (picked == null || _disposed) return;
    date = picked;
    if (endDate != null && endDate!.isBefore(date)) {
      endDate = date;
    }
    notifyListeners();
  }

  Future<void> pickEndDate(BuildContext context) async {
    final picked = await _pickNormalizedDate(
      context,
      initial: endDate ?? date,
      first: date,
    );
    if (picked == null || _disposed) return;
    endDate = picked;
    notifyListeners();
  }

  void setEndDateEnabled(bool value) {
    hasEndDate = value;
    if (value) endDate ??= date;
    notifyListeners();
  }

  Future<void> save(BuildContext context) async {
    final magnitude = parsedAmount!.abs();
    final signedEntry = signedEntryForSave(
      kind: kind,
      magnitude: magnitude,
      id: entry?.id,
      date: date,
      name: nameController.text.trim(),
      categoryId: categoryId,
      sourceId: sourceId!,
      destinationId: destinationId,
      includeInAnalysis: includeInAnalysis,
    );

    try {
      if (mode == EntryFormMode.editing) {
        ledger.updateEntry(signedEntry);
        error = null;
        mode = EntryFormMode.viewing;
        notifyListeners();
        return;
      }

      final currentRecurrence = recurrence;
      if (currentRecurrence == null) {
        ledger.addEntry(signedEntry);
      } else {
        final template = EntryTemplate(
          amount: signedEntry.amount,
          name: signedEntry.name,
          categoryID: signedEntry.categoryID,
          sourceID: signedEntry.sourceID,
          destinationID: signedEntry.destinationID,
          includeInAnalysis: signedEntry.includeInAnalysis,
        );
        final plan = buildRecurringPlanForNewEntry(
          template: template,
          frequency: currentRecurrence,
          anchor: date,
          endDate: hasEndDate ? endDate : null,
        );
        ledger.addPlan(plan);
        ledger.resolvePlans(DateTime.now().toUtc());
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();
    } on LedgerError catch (thrown) {
      error = thrown;
      notifyListeners();
    }
  }

  void delete(BuildContext context) {
    ledger.deleteEntry(entry!.id);
    Navigator.of(context).pop();
  }

  String? sourceLabel(String? id) => ledger.state.sourceName(id);

  String? categoryLabel(String? id) {
    if (id == null) return null;
    final category = ledger.state.categories[id];
    if (category == null) return null;
    final parentID = category.parentID;
    if (parentID == null) return category.name;
    final parent = ledger.state.categories[parentID];
    return parent == null ? category.name : '${parent.name}/${category.name}';
  }
}
