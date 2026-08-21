import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/swipe_to_delete_row.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/settings/plan_form.dart';
import 'package:spendwise/ui/settings/plan_sort.dart';
import 'package:spendwise/ui/common/delete_confirmation.dart';

const Map<RecurrenceFrequency, String> _frequencyLabels = {
  RecurrenceFrequency.weekly: 'Weekly',
  RecurrenceFrequency.biweekly: 'Biweekly',
  RecurrenceFrequency.monthly: 'Monthly',
  RecurrenceFrequency.quarterly: 'Quarterly',
  RecurrenceFrequency.yearly: 'Yearly',
};

class PlanListScreen extends StatefulWidget {
  const PlanListScreen({super.key, required this.ledger});

  final Ledger ledger;

  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<PlanListScreen> {
  bool _editing = false;

  void _toggleEditing() => setState(() => _editing = !_editing);

  Future<bool> _deletePlan(RecurringPlan plan) async {
    final confirmed = await showDeleteConfirmation(
      context,
      itemName: plan.template.name,
    );
    if (confirmed) widget.ledger.deletePlan(plan.id);
    return confirmed;
  }

  Widget _planList(List<RecurringPlan> plans) {
    if (plans.isEmpty) {
      return const Center(child: Text('No recurring plans yet'));
    }

    return ListView(
      children: [
        for (final plan in plans)
          SwipeToDeleteRow(
            itemKey: ValueKey('plan-${plan.id}'),
            itemName: plan.template.name,
            onDeleted: () => widget.ledger.deletePlan(plan.id),
            child: _PlanRow(
              plan: plan,
              state: widget.ledger.state,
              editing: _editing,
              onTap: () => showPlanFormSheet(
                context: context,
                ledger: widget.ledger,
                plan: plan,
              ),
              onDelete: () => _deletePlan(plan),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ledger,
      builder: (context, _) {
        final plans = sortedPlans(
          widget.ledger.state.plans.values.toList(),
          widget.ledger.state,
          DateTime.now(),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Recurring Plans'),
            actions: [
              if (plans.isNotEmpty)
                TextButton(
                  onPressed: _toggleEditing,
                  child: Text(_editing ? 'Done' : 'Edit'),
                ),
            ],
          ),
          body: _planList(plans),
        );
      },
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
