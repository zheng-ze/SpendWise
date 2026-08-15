import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/settings/plan_form_logic.dart';
import 'package:spendwise/ui/transactions/recurrence_picker.dart';

const Map<RecurrenceFrequency, String> _frequencyLabels = {
  RecurrenceFrequency.weekly: 'Weekly',
  RecurrenceFrequency.biweekly: 'Biweekly',
  RecurrenceFrequency.monthly: 'Monthly',
  RecurrenceFrequency.quarterly: 'Quarterly',
  RecurrenceFrequency.yearly: 'Yearly',
};

Future<void> showPlanFormSheet({
  required BuildContext context,
  required Ledger ledger,
  required RecurringPlan plan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.95,
      child: PlanForm(ledger: ledger, plan: plan),
    ),
  );
}

class PlanForm extends StatefulWidget {
  const PlanForm({super.key, required this.ledger, required this.plan});

  final Ledger ledger;
  final RecurringPlan plan;

  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.plan.template.name,
  );
  late final TextEditingController _amountController = TextEditingController(
    text: formatPlainAmount(widget.plan.template.amount.abs()),
  );

  late RecurrenceFrequency _frequency = widget.plan.frequency;
  late DateTime _anchor = widget.plan.anchor;
  late bool _hasEndDate = widget.plan.endDate != null;
  late DateTime? _endDate = widget.plan.endDate;

  String? _error;

  Decimal? get _parsedAmount => Decimal.tryParse(_amountController.text);

  bool get _canSave => canSavePlanForm(
    name: _nameController.text,
    amount: _parsedAmount ?? Decimal.zero,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickRecurrence() async {
    final picked = await showRecurrencePickerSheet(
      context: context,
      selected: _frequency,
    );
    setState(() => _frequency = applyPickerResult(_frequency, picked));
  }

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (picked == null) return;
    setState(
      () => _anchor = DateTime.utc(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _anchor,
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (picked == null) return;
    setState(
      () => _endDate = DateTime.utc(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _save() async {
    final originalTemplate = widget.plan.template;
    final magnitude = _parsedAmount!.abs();
    final amount = applyOriginalSign(
      magnitude: magnitude,
      originalAmount: originalTemplate.amount,
    );

    final template = EntryTemplate(
      amount: amount,
      name: _nameController.text.trim(),
      categoryID: originalTemplate.categoryID,
      sourceID: originalTemplate.sourceID,
      destinationID: originalTemplate.destinationID,
      includeInAnalysis: originalTemplate.includeInAnalysis,
    );

    final plan = RecurringPlan(
      id: widget.plan.id,
      template: template,
      frequency: _frequency,
      anchor: _anchor,
      endDate: _hasEndDate ? _endDate : null,
      lastResolvedDate: widget.plan.lastResolvedDate,
    );

    try {
      widget.ledger.updatePlan(plan);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on LedgerError catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceName =
        widget.ledger.state.sourceName(widget.plan.template.sourceID) ??
        'Unknown';

    return FormScaffold(
      title: 'Edit Plan',
      canSave: _canSave,
      onSave: _save,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          AmountField(
            controller: _amountController,
            allowsNegative: false,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Source: $sourceName'),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repeat'),
            trailing: Text(_frequencyLabels[_frequency]!),
            onTap: _pickRecurrence,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('First date'),
            trailing: Text(formatEntryDate(_anchor)),
            onTap: _pickAnchor,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date'),
            value: _hasEndDate,
            onChanged: (value) => setState(() {
              _hasEndDate = value;
              if (value) _endDate ??= _anchor;
            }),
          ),
          if (_hasEndDate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ends on'),
              trailing: Text(formatEntryDate(_endDate ?? _anchor)),
              onTap: _pickEndDate,
            ),
          ErrorSection(subject: 'plan', error: _error),
        ],
      ),
    );
  }
}
