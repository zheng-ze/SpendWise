import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';

// MARK: - Constants
const _unknownAccount = 'Unknown';

// MARK: - Helpers

List<RecurringPlan> sortedPlans(
  List<RecurringPlan> plans,
  LedgerState state,
  DateTime now,
) {
  final sorted = [...plans];
  sorted.sort((a, b) {
    final aNext = a.nextOccurrence(onOrAfter: now);
    final bNext = b.nextOccurrence(onOrAfter: now);

    final dateComparison = switch ((aNext, bNext)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final aDate?, final bDate?) => aDate.compareTo(bDate),
    };
    if (dateComparison != 0) return dateComparison;

    return a.template.name.compareTo(b.template.name);
  });
  return sorted;
}

String planCountLabel(int count) => count == 1 ? '1 plan' : '$count plans';

AmountKind _amountKind(EntryTemplate template) {
  if (template.destinationID != null) return AmountKind.transfer;
  return template.amount < Decimal.zero
      ? AmountKind.expense
      : AmountKind.income;
}

PlanRowView _planRow(RecurringPlan plan, LedgerState state, DateTime today) {
  final template = plan.template;
  final next = plan.nextOccurrence(onOrAfter: today);
  final kind = _amountKind(template);
  final account = state.sourceName(template.sourceID) ?? _unknownAccount;
  return PlanRowView(
    id: plan.id,
    name: template.name,
    day: next == null ? null : '${next.day}',
    month: next == null ? null : formatMonthShort(next),
    caption: '${addFrequencyLabels[plan.frequency]} / $account',
    amount: formatSignedMoney(template.amount, kind: kind, symbol: false),
    kind: kind,
  );
}

// MARK: - PlanRowView
class PlanRowView {
  const PlanRowView({
    required this.id,
    required this.name,
    required this.day,
    required this.month,
    required this.caption,
    required this.amount,
    required this.kind,
  });

  final String id;
  final String name;
  final String? day;
  final String? month;
  final String caption;
  final String amount;
  final AmountKind kind;

  bool get ended => day == null;
}

// MARK: - PlanListViewState
class PlanListViewState {
  const PlanListViewState({
    required this.rows,
    required this.countLabel,
    required this.selectedPlanID,
  });

  final List<PlanRowView> rows;
  final String countLabel;
  final String? selectedPlanID;
}

// MARK: - PlanListViewModel
abstract class PlanListViewModel {
  void selectPlan(String id);
}

// MARK: - PlanListNotifier
class PlanListNotifier extends AsyncNotifier<PlanListViewState>
    with LedgerBackedNotifier<PlanListViewState>
    implements PlanListViewModel {
  @override
  PlanListViewState build() {
    final currentLedger = ledger;
    final today = ref.watch(todayProvider);
    final selectedID = ref.watch(selectedPlanProvider);
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _viewState(today, selectedID);
  }

  void _onLedgerChanged() {
    final today = ref.read(todayProvider);
    final selectedID = ref.read(selectedPlanProvider);
    state = AsyncData(_viewState(today, selectedID));
  }

  PlanListViewState _viewState(DateTime today, String? selectedID) {
    final ledgerState = ledger.state;
    final plans = sortedPlans(
      ledgerState.plans.values.toList(),
      ledgerState,
      today,
    );
    return PlanListViewState(
      rows: [for (final plan in plans) _planRow(plan, ledgerState, today)],
      countLabel: planCountLabel(plans.length),
      selectedPlanID: selectedID,
    );
  }

  @override
  void selectPlan(String id) =>
      ref.read(selectedPlanProvider.notifier).select(id);
}

// MARK: - Constants
final planListViewModelProvider =
    AsyncNotifierProvider.autoDispose<PlanListNotifier, PlanListViewState>(
      PlanListNotifier.new,
      retry: (_, _) => null,
    );
