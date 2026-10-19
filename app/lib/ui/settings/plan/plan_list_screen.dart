import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/feedback/delete_confirmation.dart';
import 'package:spendwise/ui/common/lists/swipe_row.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/settings/plan/plan_form.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';

// MARK: - Constants

const _semiBoldWeight = FontWeight.w600;

const Map<RecurrenceFrequency, String> _frequencyLabels = {
  RecurrenceFrequency.weekly: 'Weekly',
  RecurrenceFrequency.biweekly: 'Biweekly',
  RecurrenceFrequency.monthly: 'Monthly',
  RecurrenceFrequency.quarterly: 'Quarterly',
  RecurrenceFrequency.yearly: 'Yearly',
};

// MARK: - PlanListScreen
class PlanListScreen extends ConsumerStatefulWidget {
  const PlanListScreen({super.key, this.embeddedRoot = false});

  final bool embeddedRoot;

  @override
  ConsumerState<PlanListScreen> createState() => _PlanListScreenState();
}

// MARK: - PlanListScreenState
class _PlanListScreenState extends ConsumerState<PlanListScreen> {
  ProviderSubscription<AsyncValue<PlanListViewState>>? _stepSubscription;

  bool _active = false;
  PlanListStep? _presentingStep;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = DestinationActivity.of(context);
    final activated = active && !_active;
    _active = active;
    if (activated) WidgetsBinding.instance.addPostFrameCallback(_pickUpStep);
  }

  void _pickUpStep(Duration _) {
    if (mounted) _handleStep(ref.read(planListViewModelProvider).value?.step);
  }

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
    if (step == null || !DestinationActivity.of(context)) return;
    if (!identical(ref.read(planListViewModelProvider).value?.step, step)) {
      return;
    }
    if (identical(_presentingStep, step)) return;

    switch (step) {
      case PlanFormRequested(:final plan):
        _viewModel.clearStep();
        _openPlanForm(plan);
      case DeleteConfirmationRequested():
        _presentingStep = step;
        _confirmDelete(step);
    }
  }

  Future<void> _openPlanForm(RecurringPlan plan) async {
    await showPlanFormSheet(context: context, plan: plan);
  }

  Future<void> _confirmDelete(DeleteConfirmationRequested step) async {
    final confirmed = await showDeleteConfirmation(
      context,
      itemName: step.plan.template.name,
    );
    if (!mounted) return;
    if (identical(ref.read(planListViewModelProvider).value?.step, step)) {
      _viewModel.applyDeleteConfirmed(confirmed);
      _viewModel.clearStep();
    }
    _presentingStep = null;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(planListViewModelProvider);
    final viewModel = ref.watch(planListViewModelProvider.notifier);

    return asyncState.when(
      data: (viewState) => _PlanListScreenBody(
        viewState: viewState,
        viewModel: viewModel,
        embeddedRoot: widget.embeddedRoot,
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

// MARK: - PlanListScreenBody
class _PlanListScreenBody extends StatelessWidget {
  const _PlanListScreenBody({
    required this.viewState,
    required this.viewModel,
    required this.embeddedRoot,
  });

  final bool embeddedRoot;

  final PlanListViewState viewState;
  final PlanListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final plans = viewState.plans;

    final actions = <Widget>[];
    if (plans.isNotEmpty) {
      actions.add(
        TextButton(
          onPressed: viewModel.toggleEditing,
          child: Text(viewState.editing ? 'Done' : 'Edit'),
        ),
      );
    }
    final appBar = embeddedRoot
        ? null
        : AppBar(title: const Text('Recurring Plans'), actions: actions);

    return Scaffold(
      appBar: appBar,
      body: plans.isEmpty
          ? const Center(child: Text('No recurring plans yet'))
          : ListView(
              children: [
                for (final plan in plans)
                  SwipeRow(
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

// MARK: - PlanRow
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
    final amount = plan.template.amount;
    final isIncome = amount >= Decimal.zero;
    final sourceName = state.sourceName(plan.template.sourceID) ?? 'Unknown';
    final next = plan.nextOccurrence(onOrAfter: DateTime.now());

    final leading = editing
        ? IconButton(
            icon: Icon(
              Icons.remove_circle,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: onDelete,
          )
        : null;
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_frequencyLabels[plan.frequency]} · $sourceName'),
        Text(next == null ? 'Ended' : 'Next: ${formatEntryDate(next)}'),
      ],
    );
    final trailing = Text(
      formatMoney(amount.abs(), symbol: false),
      style: TextStyle(
        color: AmountStyle.of(
          context,
          kind: isIncome ? AmountKind.income : AmountKind.expense,
        ).color,
        fontWeight: _semiBoldWeight,
      ),
    );

    return ListTile(
      leading: leading,
      title: Text(plan.template.name),
      subtitle: subtitle,
      isThreeLine: true,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
