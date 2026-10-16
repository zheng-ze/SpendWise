import 'package:domain/domain.dart';

import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

// MARK: - Mode

enum EntryFormMode { newEntry, viewing, editing }

// MARK: - State

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
    this.noteText = '',
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

  final String? entryId;

  final String noteText;

  final LedgerError? error;

  final bool scanning;

  final ReceiptScanStop? scanStop;

  final bool dismissed;

  @override
  final TransactionsStep? step;

  // MARK: - Derived

  Decimal? get parsedAmount => parseAmountInput(amountText);

  bool get canSave => canSaveEntryForm(
    amount: parsedAmount,
    name: nameText,
    sourceId: sourceId,
    kind: kind,
    destinationId: destinationId,
  );

  // MARK: - Copy

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
    String? noteText,
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
      noteText: noteText ?? this.noteText,
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
