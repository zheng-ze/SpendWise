import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_state.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

export 'package:spendwise/ui/transactions/entry/entry_form_state.dart';

// MARK: - View Model Contract

abstract class EntryFormViewModel {
  void setKind(EntryFormKind kind);
  void setAmount(String raw);
  void setName(String raw);
  void setIncludeInAnalysis(bool value);
  void setEndDateEnabled(bool value);
  void requestPickDate();
  void applyPickedDate(DateTime? date);
  void requestPickEndDate();
  void applyPickedEndDate(DateTime? date);
  void requestPickSource();
  void applyPickedSource(String? id);
  void requestPickDestination();
  void applyPickedDestination(String? id);
  void requestPickCategory();
  void applyPickedCategory(String? id);
  void requestPickRecurrence();
  void applyPickedRecurrence(RecurrenceFrequency? frequency);
  void startEditing();
  void revertToPersisted();
  Future<void> save();
  Future<void> delete();
  void cancel();
  void requestDocumentCrop(Uint8List bytes);

  void prefillSource(String? id);
  void clearStep();
}

// MARK: - Scan Contract

abstract class ReceiptScanController {
  void requestScan(ReceiptScanSource source, {Uint8List? preCapturedBytes});
  void applyCroppedDocument(Uint8List bytes);

  void clearScanStop();
}

// MARK: - Notifier

class EntryFormNotifier extends AsyncNotifier<EntryFormViewState>
    with
        LedgerBackedNotifier<EntryFormViewState>,
        StepEmitting<EntryFormViewState, TransactionsStep>
    implements EntryFormViewModel, ReceiptScanController {
  EntryFormNotifier(this.entryId);

  final String? entryId;

  ReceiptEntryCoordinator? _coordinator;
  bool Function()? _isAddCurrent;

  Entry? get _persisted =>
      entryId == null ? null : ledger.state.entries[entryId];

  static EntryFormKind _kindOf(Entry? entry) {
    if (entry == null) return EntryFormKind.expense;
    if (entry.isTransfer) return EntryFormKind.transfer;
    return entry.amount < Decimal.zero
        ? EntryFormKind.expense
        : EntryFormKind.income;
  }

  static DateTime _todayUtc() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  void bindAddLifetime(bool Function() isCurrent) => _isAddCurrent = isCurrent;

  bool get _addActive => _isAddCurrent?.call() ?? true;

  @override
  Future<EntryFormViewState> build() async {
    final entry = _persisted;
    _coordinator = ref.read<ReceiptEntryCoordinator>(
      receiptEntryCoordinatorProvider(entryId).notifier,
    );
    ref.listen(receiptEntryCoordinatorProvider(entryId), (_, next) {
      updateState(
        (current) => current.copyWith(
          scanning: next.scanning,
          scanStop: () => next.scanStop,
        ),
      );
    });
    return EntryFormViewState(
      mode: entry == null ? EntryFormMode.newEntry : EntryFormMode.viewing,
      kind: _kindOf(entry),
      amountText: entry == null ? '' : formatPlainAmount(entry.amount.abs()),
      nameText: entry?.name ?? '',
      date: entry?.date ?? _todayUtc(),
      sourceId: entry?.sourceID,
      destinationId: entry?.destinationID,
      categoryId: entry?.categoryID,
      includeInAnalysis: entry?.includeInAnalysis ?? true,
      recurrence: null,
      hasEndDate: false,
      endDate: null,
      isSystemEntry: entry?.systemKind != null,
      entryId: entry?.id,
    );
  }

  // MARK: - Field Setters

  @override
  void setKind(EntryFormKind kind) {
    updateState(
      (current) => current.copyWith(
        kind: kind,
        categoryId: () => null,
        destinationId: kind == EntryFormKind.transfer ? null : () => null,
      ),
    );
  }

  @override
  void setAmount(String raw) =>
      updateState((current) => current.copyWith(amountText: raw));

  @override
  void setName(String raw) =>
      updateState((current) => current.copyWith(nameText: raw));

  @override
  void setIncludeInAnalysis(bool value) =>
      updateState((current) => current.copyWith(includeInAnalysis: value));

  @override
  void setEndDateEnabled(bool value) {
    updateState(
      (current) => current.copyWith(
        hasEndDate: value,
        endDate: !value || current.endDate != null ? null : () => current.date,
      ),
    );
  }

  // MARK: - Pickers

  @override
  void requestPickDate() => emitStep(PickDateRequested());

  @override
  void applyPickedDate(DateTime? date) {
    if (date == null) return;
    updateState((current) {
      final endDate = current.endDate;
      final adjustedEnd = endDate != null && endDate.isBefore(date)
          ? date
          : endDate;
      return current.copyWith(date: date, endDate: () => adjustedEnd);
    });
  }

  @override
  void requestPickEndDate() => emitStep(PickEndDateRequested());

  @override
  void applyPickedEndDate(DateTime? date) {
    if (date == null) return;
    updateState((current) => current.copyWith(endDate: () => date));
  }

  @override
  void requestPickSource() => emitStep(PickSourceRequested());

  @override
  void applyPickedSource(String? id) =>
      updateState((current) => current.copyWith(sourceId: () => id));

  @override
  void requestPickDestination() => emitStep(PickDestinationRequested());

  @override
  void applyPickedDestination(String? id) =>
      updateState((current) => current.copyWith(destinationId: () => id));

  @override
  void requestPickCategory() => emitStep(PickCategoryRequested());

  @override
  void applyPickedCategory(String? id) =>
      updateState((current) => current.copyWith(categoryId: () => id));

  @override
  void requestPickRecurrence() => emitStep(PickRecurrenceRequested());

  @override
  void applyPickedRecurrence(RecurrenceFrequency? frequency) {
    updateState(
      (current) => current.copyWith(
        recurrence: () => frequency,
        hasEndDate: frequency == null ? false : current.hasEndDate,
        endDate: frequency == null ? () => null : null,
      ),
    );
  }

  // MARK: - Editing Lifecycle

  @override
  void startEditing() =>
      updateState((current) => current.copyWith(mode: EntryFormMode.editing));

  @override
  void revertToPersisted() {
    final entry = _persisted;
    if (entry == null) return;
    updateState(
      (current) => EntryFormViewState(
        mode: EntryFormMode.viewing,
        kind: _kindOf(entry),
        amountText: formatPlainAmount(entry.amount.abs()),
        nameText: entry.name,
        date: entry.date,
        sourceId: entry.sourceID,
        destinationId: entry.destinationID,
        categoryId: entry.categoryID,
        includeInAnalysis: entry.includeInAnalysis,
        recurrence: null,
        hasEndDate: false,
        endDate: null,
        isSystemEntry: entry.systemKind != null,
        entryId: entry.id,
      ),
    );
  }

  // MARK: - Persistence

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null || !current.canSave || !_addActive) return;

    final magnitude = current.parsedAmount!.abs();
    final signedEntry = signedEntryForSave(
      kind: current.kind,
      magnitude: magnitude,
      id: current.entryId,
      date: current.date,
      name: current.nameText.trim(),
      categoryId: current.categoryId,
      sourceId: current.sourceId!,
      destinationId: current.destinationId,
      includeInAnalysis: current.includeInAnalysis,
    );

    try {
      if (current.mode == EntryFormMode.editing) {
        ledger.updateEntry(signedEntry);
        updateState(
          (c) => c.copyWith(mode: EntryFormMode.viewing, error: () => null),
        );
        return;
      }

      final recurrence = current.recurrence;
      if (recurrence == null) {
        ledger.addEntry(signedEntry);
      } else {
        ledger.addPlan(_recurringPlanFor(current, signedEntry, recurrence));
        ledger.resolvePlans(startOfDayUtc(DateTime.now()));
      }
      updateState((c) => c.copyWith(dismissed: true));
    } on LedgerError catch (thrown) {
      updateState((c) => c.copyWith(error: () => thrown));
    }
  }

  RecurringPlan _recurringPlanFor(
    EntryFormViewState current,
    Entry signedEntry,
    RecurrenceFrequency frequency,
  ) {
    final template = EntryTemplate(
      amount: signedEntry.amount,
      name: signedEntry.name,
      categoryID: signedEntry.categoryID,
      sourceID: signedEntry.sourceID,
      destinationID: signedEntry.destinationID,
      includeInAnalysis: signedEntry.includeInAnalysis,
    );
    return RecurringPlan(
      template: template,
      frequency: frequency,
      anchor: current.date,
      endDate: current.hasEndDate ? current.endDate : null,
      lastResolvedDate: current.date.subtract(const Duration(days: 1)),
    );
  }

  @override
  Future<void> delete() async {
    final id = state.value?.entryId;
    if (id == null) return;
    ledger.deleteEntry(id);
    updateState((current) => current.copyWith(dismissed: true));
  }

  @override
  void cancel() => updateState((c) => c.copyWith(dismissed: true));

  // MARK: - Receipt Scan

  @override
  void requestScan(ReceiptScanSource source, {Uint8List? preCapturedBytes}) {
    if (!_addActive) return;
    unawaited(
      _coordinator!.requestScan(
        source,
        preCapturedBytes: preCapturedBytes,
        onPrefill: _applyScanResult,
      ),
    );
  }

  @override
  void prefillSource(String? id) {
    if (id == null) return;
    updateState((current) {
      if (current.mode != EntryFormMode.newEntry) return current;
      if (current.sourceId != null) return current;
      return current.copyWith(sourceId: () => id);
    });
  }

  void _applyScanResult({
    String? name,
    Decimal? amount,
    required DateTime date,
  }) {
    updateState(
      (current) => current.copyWith(
        nameText: name ?? current.nameText,
        amountText: amount == null
            ? current.amountText
            : formatPlainAmount(amount),
        date: date,
      ),
    );
  }

  @override
  void requestDocumentCrop(Uint8List bytes) =>
      emitStep(DocumentCropRequested(bytes));

  @override
  void applyCroppedDocument(Uint8List bytes) {
    if (!_addActive) return;
    _coordinator!.applyCroppedDocument(bytes, onPrefill: _applyScanResult);
  }

  @override
  void clearScanStop() => _coordinator!.clearScanStop();
}

// MARK: - Provider

final entryFormViewModelProvider =
    AsyncNotifierProvider.family<
      EntryFormNotifier,
      EntryFormViewState,
      String?
    >(EntryFormNotifier.new);
