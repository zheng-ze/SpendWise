import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/delete_confirmation.dart';
import 'package:spendwise/ui/common/swipe_to_delete_row.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/settings/plan/plan_form.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';

const Map<RecurrenceFrequency, String> _frequencyLabels = {
  RecurrenceFrequency.weekly: 'Weekly',
  RecurrenceFrequency.biweekly: 'Biweekly',
  RecurrenceFrequency.monthly: 'Monthly',
  RecurrenceFrequency.quarterly: 'Quarterly',
  RecurrenceFrequency.yearly: 'Yearly',
};

class PlanListScreen extends ConsumerStatefulWidget {
  const PlanListScreen({super.key});

  @override
  ConsumerState<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends ConsumerState<PlanListScreen> {
  ProviderSubscription<AsyncValue<PlanListViewState>>? _stepSubscription;

  @override
  void initState() {
    super.initState();
    _stepSubscription = ref.listenManual(
      planListViewModelProvider,
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _stepSubscription?.close();
    super.dispose();
  }

  PlanListViewModel get _viewModel =>
      ref.read(planListViewModelProvider.notifier);

  void _handleStep(PlanListStep? step) {
    if (step == null) return;

    switch (step) {
      case PlanFormRequested(:final plan):
        _openPlanForm(plan);
      case DeleteConfirmationRequested(:final plan):
        _confirmDelete(plan);
    }
  }

  Future<void> _openPlanForm(RecurringPlan plan) async {
    _viewModel.clearStep();
    await showPlanFormSheet(context: context, plan: plan);
  }

  Future<void> _confirmDelete(RecurringPlan plan) async {
    final confirmed = await showDeleteConfirmation(
      context,
      itemName: plan.template.name,
    );
    _viewModel.applyDeleteConfirmed(confirmed);
    _viewModel.clearStep();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(planListViewModelProvider);
    final viewModel = ref.watch(planListViewModelProvider.notifier);

    return asyncState.when(
      data: (viewState) =>
          _PlanListScreenBody(viewState: viewState, viewModel: viewModel),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _PlanListScreenBody extends StatelessWidget {
  const _PlanListScreenBody({required this.viewState, required this.viewModel});

  final PlanListViewState viewState;
  final PlanListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final plans = viewState.plans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Plans'),
        actions: [
          if (plans.isNotEmpty)
            TextButton(
              onPressed: viewModel.toggleEditing,
              child: Text(viewState.editing ? 'Done' : 'Edit'),
            ),
        ],
      ),
      body: plans.isEmpty
          ? const Center(child: Text('No recurring plans yet'))
          : ListView(
              children: [
                for (final plan in plans)
                  SwipeToDeleteRow(
                    itemKey: ValueKey('plan-${plan.id}'),
                    itemName: plan.template.name,
                    onDeleted: () => viewModel.deletePlan(plan.id),
                    child: _PlanRow(
                      plan: plan,
                      state: viewState.ledgerState,
                      editing: viewState.editing,
                      onTap: () => viewModel.requestEditPlan(plan),
                      onDelete: () => viewModel.requestDeletePlan(plan.id),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.state,
    required this.editing,
    required this.onTap,
    required this.onDelete,
  });

  final RecurringPlan plan;
  final LedgerState state;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AmountColors.of(Theme.of(context));
    final amount = plan.template.amount;
    final isIncome = amount >= Decimal.zero;
    final sourceName = state.sourceName(plan.template.sourceID) ?? 'Unknown';
    final next = plan.nextOccurrence(onOrAfter: DateTime.now());

    return ListTile(
      leading: editing
          ? IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: onDelete,
            )
          : null,
      title: Text(plan.template.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_frequencyLabels[plan.frequency]} · $sourceName'),
          Text(next == null ? 'Ended' : 'Next: ${formatEntryDate(next)}'),
        ],
      ),
      isThreeLine: true,
      trailing: Text(
        formatCurrency(amount.abs()),
        style: TextStyle(
          color: isIncome ? colors.gain : colors.neutral,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
