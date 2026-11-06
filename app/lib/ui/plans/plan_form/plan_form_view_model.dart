import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/format/amount_parse.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/plans/plan_projection.dart';

// MARK: - Helpers
bool canSavePlanForm({required String name, required Decimal amount}) {
  if (name.trim().isEmpty) return false;
  if (amount == Decimal.zero) return false;
  return true;
}

Decimal applyOriginalSign({
  required Decimal magnitude,
  required Decimal originalAmount,
}) {
  return originalAmount < Decimal.zero ? -magnitude : magnitude;
}

// MARK: - Steps
sealed class PlanFormStep {}

class PickRecurrenceRequested extends PlanFormStep {}

class PickAnchorRequested extends PlanFormStep {}

class PickEndDateRequested extends PlanFormStep {}

class PlanFormSaved extends PlanFormStep {}

// MARK: - PlanFormViewState
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

// MARK: - PlanFormViewModel
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

// MARK: - PlanFormNotifier
class PlanFormNotifier extends AsyncNotifier<PlanFormViewState>
    with
        LedgerBackedNotifier<PlanFormViewState>,
        StepEmitting<PlanFormViewState, PlanFormStep>
    implements PlanFormViewModel {
  PlanFormNotifier(this._planID);

  final String _planID;

  RecurringPlan _plan() {
    final plan = ledger.state.plans[_planID];
    if (plan == null) {
      throw StateError('No plan with id $_planID.');
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
      sourceName: planAccountName(ledger.state, plan.template.sourceID),
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
    updateState((s) => s.copyWith(frequency: picked, step: () => null));
  }

  @override
  void requestPickAnchor() => emitStep(PickAnchorRequested());

  @override
  void applyPickedAnchor(DateTime? picked) {
    final anchor = picked == null ? null : startOfDayUtc(picked);
    updateState((s) => s.copyWith(anchor: anchor, step: () => null));
  }

  @override
  void setHasEndDate(bool value) {
    updateState(
      (s) => s.copyWith(
        hasEndDate: value,
        endDate: () => value ? s.endDate ?? s.anchor : null,
      ),
    );
  }

  @override
  void requestPickEndDate() => emitStep(PickEndDateRequested());

  @override
  void applyPickedEndDate(DateTime? picked) {
    final endDate = picked == null ? null : () => startOfDayUtc(picked);
    updateState((s) => s.copyWith(endDate: endDate, step: () => null));
  }

  @override
  Future<void> save() async {
    final current = state.value;
    if (current == null) return;

    final stored = ledger.state.plans[_planID];
    if (stored == null) {
      updateState((s) => s.copyWith(error: () => UnknownPlan(_planID)));
      return;
    }

    final originalTemplate = stored.template;
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
      note: originalTemplate.note,
    );

    final plan = RecurringPlan(
      id: _planID,
      template: template,
      frequency: current.frequency,
      anchor: current.anchor,
      endDate: current.hasEndDate ? current.endDate : null,
      lastResolvedDate: stored.lastResolvedDate,
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

// MARK: - Constants
final planFormViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<PlanFormNotifier, PlanFormViewState, String>(
      PlanFormNotifier.new,
      retry: (_, _) => null,
    );
