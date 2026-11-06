import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/plans/plan_projection.dart';

// MARK: - Helpers

List<RecurringPlan> sortedPlans(List<RecurringPlan> plans, DateTime now) {
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

PlanRowView _planRow(RecurringPlan plan, LedgerState state, DateTime today) {
  final template = plan.template;
  final next = plan.nextOccurrence(onOrAfter: today);
  final kind = planAmountKind(template);
  final account = planAccountName(state, template.sourceID);
  final nextDate = next == null
      ? null
      : (day: '${next.day}', month: formatMonthShort(next));
  return PlanRowView(
    id: plan.id,
    name: template.name,
    nextDate: nextDate,
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
    required this.nextDate,
    required this.caption,
    required this.amount,
    required this.kind,
  });

  final String id;
  final String name;
  final ({String day, String month})? nextDate;
  final String caption;
  final String amount;
  final AmountKind kind;
}

// MARK: - PlanListViewState
class PlanListViewState {
  const PlanListViewState({required this.rows, required this.countLabel});

  final List<PlanRowView> rows;
  final String countLabel;
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
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _viewState(today);
  }

  void _onLedgerChanged() =>
      state = AsyncData(_viewState(ref.read(todayProvider)));

  PlanListViewState _viewState(DateTime today) {
    final ledgerState = ledger.state;
    final plans = sortedPlans(ledgerState.plans.values.toList(), today);
    return PlanListViewState(
      rows: [for (final plan in plans) _planRow(plan, ledgerState, today)],
      countLabel: planCountLabel(plans.length),
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
