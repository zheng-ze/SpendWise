import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/amount_color.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/settings/plan_form.dart';
import 'package:spendwise/ui/settings/plan_sort.dart';

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

  Future<bool> _confirmDelete(RecurringPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${plan.template.name}?'),
        content: const Text('Already generated transactions are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
          body: plans.isEmpty
              ? const Center(child: Text('No recurring plans yet'))
              : ListView(
                  children: [
                    for (final plan in plans)
                      Dismissible(
                        key: ValueKey('plan-${plan.id}'),
                        direction: DismissDirection.endToStart,
                        background: const _DeleteBackground(),
                        confirmDismiss: (_) => _confirmDelete(plan),
                        onDismissed: (_) => widget.ledger.deletePlan(plan.id),
                        child: _PlanRow(
                          plan: plan,
                          state: widget.ledger.state,
                          editing: _editing,
                          onTap: () => showPlanFormSheet(
                            context: context,
                            ledger: widget.ledger,
                            plan: plan,
                          ),
                          onDelete: () async {
                            if (await _confirmDelete(plan)) {
                              widget.ledger.deletePlan(plan.id);
                            }
                          },
                        ),
                      ),
                  ],
                ),
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

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.error,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
