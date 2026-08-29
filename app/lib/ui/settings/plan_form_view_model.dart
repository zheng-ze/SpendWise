import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';

bool canSavePlanForm({required String name, required Decimal amount}) {
  if (name.trim().isEmpty) return false;
  if (amount == Decimal.zero) return false;
  return true;
}

/// Carries the template's original sign onto the freshly typed magnitude.
Decimal applyOriginalSign({
  required Decimal magnitude,
  required Decimal originalAmount,
}) {
  // Keeps an expense plan from silently becoming an income plan through this form.
  return originalAmount < Decimal.zero ? -magnitude : magnitude;
}

/// Returns [picked], or [current] if the picker returned null.
RecurrenceFrequency applyPickerResult(
  RecurrenceFrequency current,
  RecurrenceFrequency? picked,
) => picked ?? current;

sealed class PlanFormStep {}

class PickRecurrenceRequested extends PlanFormStep {}

class PickAnchorRequested extends PlanFormStep {}

class PickEndDateRequested extends PlanFormStep {}

class PlanFormSaved extends PlanFormStep {}

class PlanFormViewState implements HasStep<PlanFormViewState, PlanFormStep> {
  const PlanFormViewState({
    required this.name,
    required this.amountText,
    required this.frequency,
    required this.anchor,
    required this.hasEndDate,
    required this.endDate,
    required this.sourceName,
    this.error,
    this.step,
  });

  final String name;
  final String amountText;
  final RecurrenceFrequency frequency;
  final DateTime anchor;
  final bool hasEndDate;
  final DateTime? endDate;
  final String sourceName;
  final LedgerError? error;
  @override
  final PlanFormStep? step;

  Decimal? get parsedAmount => parseAmountInput(amountText);

  bool get canSave =>
      canSavePlanForm(name: name, amount: parsedAmount ?? Decimal.zero);

  PlanFormViewState copyWith({
    String? name,
    String? amountText,
    RecurrenceFrequency? frequency,
    DateTime? anchor,
    bool? hasEndDate,
    DateTime? Function()? endDate,
    LedgerError? Function()? error,
    PlanFormStep? Function()? step,
  }) {
    return PlanFormViewState(
      name: name ?? this.name,
      amountText: amountText ?? this.amountText,
      frequency: frequency ?? this.frequency,
      anchor: anchor ?? this.anchor,
      hasEndDate: hasEndDate ?? this.hasEndDate,
      endDate: endDate == null ? this.endDate : endDate(),
      sourceName: sourceName,
      error: error == null ? this.error : error(),
      step: step == null ? this.step : step(),
    );
  }

  @override
  PlanFormViewState withStep(PlanFormStep? Function() step) =>
      copyWith(step: step);
}

abstract class PlanFormViewModel {
  void setName(String raw);
  void setAmount(String raw);
  void requestPickRecurrence();
  void applyPickedRecurrence(RecurrenceFrequency? picked);
  void requestPickAnchor();
  void applyPickedAnchor(DateTime? picked);
  void setHasEndDate(bool value);
  void requestPickEndDate();
  void applyPickedEndDate(DateTime? picked);
  Future<void> save();
  void clearStep();
}

class PlanFormNotifier extends AsyncNotifier<PlanFormViewState>
    with
        LedgerBackedNotifier<PlanFormViewState>,
        StepEmitting<PlanFormViewState, PlanFormStep>
    implements PlanFormViewModel {
  PlanFormNotifier(this._planId);

  final String _planId;

  RecurringPlan _plan() {
    final plan = ledger.state.plans[_planId];
    if (plan == null) {
      throw StateError('No plan with id $_planId.');
    }
    return plan;
  }

  @override
  Future<PlanFormViewState> build() async {
    final plan = _plan();
    return PlanFormViewState(
      name: plan.template.name,
      amountText: formatPlainAmount(plan.template.amount.abs()),
      frequency: plan.frequency,
      anchor: plan.anchor,
      hasEndDate: plan.endDate != null,
      endDate: plan.endDate,
      sourceName: ledger.state.sourceName(plan.template.sourceID) ?? 'Unknown',
    );
  }

  @override
  void setName(String raw) => updateState((s) => s.copyWith(name: raw));

  @override
  void setAmount(String raw) => updateState((s) => s.copyWith(amountText: raw));

  @override
  void requestPickRecurrence() => emitStep(PickRecurrenceRequested());

  @override
  void applyPickedRecurrence(RecurrenceFrequency? picked) {
    if (!ref.mounted) return;
    updateState(
      (s) => s.copyWith(
        frequency: applyPickerResult(s.frequency, picked),
        step: () => null,
      ),
    );
  }

  @override
  void requestPickAnchor() => emitStep(PickAnchorRequested());

  @override
  void applyPickedAnchor(DateTime? picked) {
    if (!ref.mounted) return;
    if (picked == null) {
      updateState((s) => s.copyWith(step: () => null));
      return;
    }
    updateState(
      (s) => s.copyWith(
        anchor: DateTime.utc(picked.year, picked.month, picked.day),
        step: () => null,
      ),
    );
  }

  @override
  void setHasEndDate(bool value) {
    updateState(
      (s) => s.copyWith(
        hasEndDate: value,
        // Turning the toggle off leaves endDate as-is; save() gates on
        // hasEndDate, not endDate, so a stale date here is harmless.
        endDate: value ? () => s.endDate ?? s.anchor : null,
      ),
    );
  }

  @override
  void requestPickEndDate() => emitStep(PickEndDateRequested());

  @override
  void applyPickedEndDate(DateTime? picked) {
    if (!ref.mounted) return;
    if (picked == null) {
      updateState((s) => s.copyWith(step: () => null));
      return;
    }
    updateState(
      (s) => s.copyWith(
        endDate: () => DateTime.utc(picked.year, picked.month, picked.day),
        step: () => null,
      ),
    );
  }

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null) return;

    final originalTemplate = _plan().template;
    // canSave requires a non-null parse, and the Save button gates this
    // call on canSave, so the amount is never null here.
    final magnitude = current.parsedAmount!.abs();
    final amount = applyOriginalSign(
      magnitude: magnitude,
      originalAmount: originalTemplate.amount,
    );

    final template = EntryTemplate(
      amount: amount,
      name: current.name.trim(),
      categoryID: originalTemplate.categoryID,
      sourceID: originalTemplate.sourceID,
      destinationID: originalTemplate.destinationID,
      includeInAnalysis: originalTemplate.includeInAnalysis,
    );

    final plan = RecurringPlan(
      id: _planId,
      template: template,
      frequency: current.frequency,
      anchor: current.anchor,
      endDate: current.hasEndDate ? current.endDate : null,
      lastResolvedDate: _plan().lastResolvedDate,
    );

    try {
      ledger.updatePlan(plan);
      updateState(
        (s) => s.copyWith(error: () => null, step: () => PlanFormSaved()),
      );
    } on LedgerError catch (error) {
      updateState((s) => s.copyWith(error: () => error));
    }
  }
}

final planFormViewModelProvider =
    AsyncNotifierProvider.family<PlanFormNotifier, PlanFormViewState, String>(
      PlanFormNotifier.new,
    );
