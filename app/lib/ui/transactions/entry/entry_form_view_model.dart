import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

enum EntryFormMode { newEntry, viewing, editing }

class EntryFormViewState
    implements HasStep<EntryFormViewState, TransactionsStep> {
  const EntryFormViewState({
    required this.mode,
    required this.kind,
    required this.amountText,
    required this.nameText,
    required this.date,
    required this.sourceId,
    required this.destinationId,
    required this.categoryId,
    required this.includeInAnalysis,
    required this.recurrence,
    required this.hasEndDate,
    required this.endDate,
    required this.isSystemEntry,
    required this.entryId,
    this.error,
    this.scanning = false,
    this.scanStop,
    this.dismissed = false,
    this.step,
  });

  final EntryFormMode mode;
  final EntryFormKind kind;
  final String amountText;
  final String nameText;
  final DateTime date;
  final String? sourceId;
  final String? destinationId;
  final String? categoryId;
  final bool includeInAnalysis;
  final RecurrenceFrequency? recurrence;
  final bool hasEndDate;
  final DateTime? endDate;
  final bool isSystemEntry;

  /// Null for a new, unsaved entry.
  final String? entryId;

  final LedgerError? error;

  /// True while a receipt scan is recognizing an image.
  final bool scanning;

  /// Set once by a scan that ended without prefilling anything, so the View
  /// can show why. Cleared the same single-shot way as [step].
  final ReceiptScanStop? scanStop;

  /// True once save or delete has completed and the sheet should close.
  final bool dismissed;

  @override
  final TransactionsStep? step;

  Decimal? get parsedAmount => parseAmountInput(amountText);

  bool get canSave => canSaveEntryForm(
    amount: parsedAmount,
    name: nameText,
    sourceId: sourceId,
    kind: kind,
    destinationId: destinationId,
  );

  EntryFormViewState copyWith({
    EntryFormMode? mode,
    EntryFormKind? kind,
    String? amountText,
    String? nameText,
    DateTime? date,
    String? Function()? sourceId,
    String? Function()? destinationId,
    String? Function()? categoryId,
    bool? includeInAnalysis,
    RecurrenceFrequency? Function()? recurrence,
    bool? hasEndDate,
    DateTime? Function()? endDate,
    LedgerError? Function()? error,
    bool? scanning,
    ReceiptScanStop? Function()? scanStop,
    bool? dismissed,
    TransactionsStep? Function()? step,
  }) {
    return EntryFormViewState(
      mode: mode ?? this.mode,
      kind: kind ?? this.kind,
      amountText: amountText ?? this.amountText,
      nameText: nameText ?? this.nameText,
      date: date ?? this.date,
      sourceId: sourceId == null ? this.sourceId : sourceId(),
      destinationId: destinationId == null
          ? this.destinationId
          : destinationId(),
      categoryId: categoryId == null ? this.categoryId : categoryId(),
      includeInAnalysis: includeInAnalysis ?? this.includeInAnalysis,
      recurrence: recurrence == null ? this.recurrence : recurrence(),
      hasEndDate: hasEndDate ?? this.hasEndDate,
      endDate: endDate == null ? this.endDate : endDate(),
      isSystemEntry: isSystemEntry,
      entryId: entryId,
      error: error == null ? this.error : error(),
      scanning: scanning ?? this.scanning,
      scanStop: scanStop == null ? this.scanStop : scanStop(),
      dismissed: dismissed ?? this.dismissed,
      step: step == null ? this.step : step(),
    );
  }

  @override
  EntryFormViewState withStep(TransactionsStep? Function() step) =>
      copyWith(step: step);
}

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
  void requestScan(ReceiptScanSource source, {Uint8List? preCapturedBytes});
  void requestDocumentCrop(Uint8List bytes);
  void applyCroppedDocument(Uint8List bytes);

  /// Prefills a brand-new entry's source from the screen's scope. A no-op
  /// once the form already has a source.
  void prefillSource(String? id);

  /// Clears a scan's reported [EntryFormViewState.scanStop] once the View
  /// has shown its message, the same single-shot discipline as [clearStep].
  void clearScanStop();
  void clearStep();
}

// One instance per entry being edited, null for a new entry, since the
// provider is a family keyed by what it edits.
class EntryFormNotifier extends AsyncNotifier<EntryFormViewState>
    with
        LedgerBackedNotifier<EntryFormViewState>,
        StepEmitting<EntryFormViewState, TransactionsStep>
    implements EntryFormViewModel {
  EntryFormNotifier(this.entryId);

  final String? entryId;

  /// The receipt-scan / crop coordinator for this entry form. Read and its
  /// state mirrored into [EntryFormViewState] in [build]; its lifetime is
  /// bound to this provider.
  ReceiptEntryCoordinator? _coordinator;

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

  @override
  Future<EntryFormViewState> build() async {
    final entry = _persisted;
    _coordinator = ref.read<ReceiptEntryCoordinator>(
      receiptEntryCoordinatorProvider(entryId).notifier,
    );
    ref.listen(receiptEntryCoordinatorProvider(entryId), (_, next) {
      updateState((current) => current.copyWith(
        scanning: next.scanning,
        scanStop: () => next.scanStop,
      ));
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

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null || !current.canSave) return;

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

  // lastResolvedDate starts one day behind the anchor so a half-open scan
  // starting after that date still includes the anchor day itself.
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
  void requestScan(ReceiptScanSource source, {Uint8List? preCapturedBytes}) {
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
  void applyCroppedDocument(Uint8List bytes) => _coordinator!.applyCroppedDocument(
    bytes,
    onPrefill: _applyScanResult,
  );

  @override
  void clearScanStop() => _coordinator!.clearScanStop();
}

final entryFormViewModelProvider =
    AsyncNotifierProvider.family<
      EntryFormNotifier,
      EntryFormViewState,
      String?
    >(EntryFormNotifier.new);
