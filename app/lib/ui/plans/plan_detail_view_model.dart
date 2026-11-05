import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/format/analysis_bucket_name.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/plans/plan_last_added.dart';
import 'package:spendwise/ui/plans/plan_steps.dart';

// MARK: - Constants
const _unknownAccountLabel = 'Unknown';
const _endedLabel = 'Ended';
const _notYetLabel = 'Not yet';
const _neverLabel = 'Never';
const _categoryRowLabel = 'Category';
const _destinationRowLabel = 'To';

// MARK: - PlanDetailViewState
enum PlanDetailPhase { shown, deleted }

typedef PlanDetailRow = ({String label, String value});

class PlanDetailViewState
    implements HasStep<PlanDetailViewState, PlanDetailStep> {
  const PlanDetailViewState({
    required this.phase,
    required this.name,
    required this.amount,
    required this.kind,
    required this.frequencyLabel,
    required this.next,
    required this.account,
    required this.relationRow,
    required this.started,
    required this.lastAdded,
    required this.ends,
    this.step,
  });

  factory PlanDetailViewState.deleted() {
    return PlanDetailViewState(
      phase: PlanDetailPhase.deleted,
      name: '',
      amount: Decimal.zero,
      kind: AmountKind.expense,
      frequencyLabel: '',
      next: '',
      account: '',
      relationRow: (label: _categoryRowLabel, value: ''),
      started: '',
      lastAdded: '',
      ends: '',
    );
  }

  final PlanDetailPhase phase;
  final String name;
  final Decimal amount;
  final AmountKind kind;
  final String frequencyLabel;
  final String next;
  final String account;
  final PlanDetailRow relationRow;
  final String started;
  final String lastAdded;
  final String ends;
  @override
  final PlanDetailStep? step;

  @override
  PlanDetailViewState withStep(PlanDetailStep? Function() step) {
    return PlanDetailViewState(
      phase: phase,
      name: name,
      amount: amount,
      kind: kind,
      frequencyLabel: frequencyLabel,
      next: next,
      account: account,
      relationRow: relationRow,
      started: started,
      lastAdded: lastAdded,
      ends: ends,
      step: step(),
    );
  }
}

PlanDetailRow _relationRow(EntryTemplate template, LedgerState ledgerState) {
  final destinationID = template.destinationID;
  if (destinationID != null) {
    return (
      label: _destinationRowLabel,
      value: ledgerState.sourceName(destinationID) ?? _unknownAccountLabel,
    );
  }
  final categoryName = ledgerState.categories[template.categoryID]?.name;
  return (label: _categoryRowLabel, value: categoryName ?? uncategorizedName);
}

AmountKind _amountKind(EntryTemplate template) {
  if (template.destinationID != null) return AmountKind.transfer;
  return template.amount >= Decimal.zero
      ? AmountKind.income
      : AmountKind.expense;
}

PlanDetailViewState _shownState(
  RecurringPlan plan,
  LedgerState ledgerState,
  DateTime today,
) {
  final template = plan.template;
  final nextDate = plan.nextOccurrence(onOrAfter: today);
  final lastAdded = lastAddedDate(plan);
  final endDate = plan.endDate;

  return PlanDetailViewState(
    phase: PlanDetailPhase.shown,
    name: template.name,
    amount: template.amount,
    kind: _amountKind(template),
    frequencyLabel: addFrequencyLabels[plan.frequency]!,
    next: nextDate == null ? _endedLabel : formatEntryDate(nextDate),
    account: ledgerState.sourceName(template.sourceID) ?? _unknownAccountLabel,
    relationRow: _relationRow(template, ledgerState),
    started: formatEntryDate(plan.anchor),
    lastAdded: lastAdded == null ? _notYetLabel : formatEntryDate(lastAdded),
    ends: endDate == null ? _neverLabel : formatEntryDate(endDate),
  );
}

// MARK: - PlanDetailNotifier
class PlanDetailNotifier extends AsyncNotifier<PlanDetailViewState>
    with
        LedgerBackedNotifier<PlanDetailViewState>,
        StepEmitting<PlanDetailViewState, PlanDetailStep> {
  PlanDetailNotifier(this._planID);

  final String _planID;

  @override
  PlanDetailViewState build() {
    final currentLedger = ledger;
    final today = ref.watch(todayProvider);
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _viewState(today);
  }

  void _onLedgerChanged() =>
      state = AsyncData(_viewState(ref.read(todayProvider)));

  PlanDetailViewState _viewState(DateTime today) {
    final ledgerState = ledger.state;
    final plan = ledgerState.plans[_planID];
    if (plan == null) return PlanDetailViewState.deleted();
    return _shownState(plan, ledgerState, today);
  }

  bool get _planExists => ledger.state.plans.containsKey(_planID);

  void requestDelete() {
    if (!_planExists) return;
    emitStep(PlanDeleteRequested());
  }

  void deletePlan() {
    if (!ref.mounted || !_planExists) return;
    ledger.deletePlan(_planID);
  }
}

// MARK: - Constants
final planDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<PlanDetailNotifier, PlanDetailViewState, String>(
      PlanDetailNotifier.new,
      retry: (_, _) => null,
    );
