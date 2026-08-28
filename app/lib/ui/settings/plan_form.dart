import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/amount_field.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/form_scaffold.dart';
import 'package:spendwise/ui/common/recurrence_picker.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/settings/plan_form_view_model.dart';

/// Opens the edit sheet for an existing recurring plan. Edit-only: plans are
/// created from the entry form's recurrence flow, never here.
Future<void> showPlanFormSheet({
  required BuildContext context,
  required RecurringPlan plan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PlanForm(planId: plan.id),
  );
}

class PlanForm extends ConsumerStatefulWidget {
  const PlanForm({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<PlanForm> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _amountController = TextEditingController();

  ProviderSubscription<AsyncValue<PlanFormViewState>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      planFormViewModelProvider(widget.planId),
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  PlanFormViewModel get _viewModel =>
      ref.read(planFormViewModelProvider(widget.planId).notifier);

  void _handleStep(PlanFormStep? step) {
    if (step == null) return;
    switch (step) {
      case PickRecurrenceRequested():
        _pickRecurrence();
      case PickAnchorRequested():
        _pickAnchor();
      case PickEndDateRequested():
        _pickEndDate();
      case PlanFormSaved():
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
    _viewModel.clearStep();
  }

  Future<void> _pickRecurrence() async {
    final formState = ref.read(planFormViewModelProvider(widget.planId)).value;
    if (formState == null) return;
    final picked = await showRecurrencePickerSheet(
      context: context,
      selected: formState.frequency,
    );
    if (!context.mounted) return;
    _viewModel.applyPickedRecurrence(picked);
  }

  Future<void> _pickAnchor() async {
    final formState = ref.read(planFormViewModelProvider(widget.planId)).value;
    if (formState == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: formState.anchor,
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (!context.mounted) return;
    _viewModel.applyPickedAnchor(picked);
  }

  Future<void> _pickEndDate() async {
    final formState = ref.read(planFormViewModelProvider(widget.planId)).value;
    if (formState == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: formState.endDate ?? formState.anchor,
      firstDate: DateTime.utc(2000),
      lastDate: DateTime.utc(2100),
    );
    if (!context.mounted) return;
    _viewModel.applyPickedEndDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(planFormViewModelProvider(widget.planId));

    return asyncState.when(
      data: (formState) => _PlanFormBody(
        formState: formState,
        viewModel: _viewModel,
        nameController: _nameController,
        amountController: _amountController,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _PlanFormBody extends StatelessWidget {
  const _PlanFormBody({
    required this.formState,
    required this.viewModel,
    required this.nameController,
    required this.amountController,
  });

  final PlanFormViewState formState;
  final PlanFormViewModel viewModel;
  final TextEditingController nameController;
  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    // Pulled from the ViewModel each build rather than bound both ways,
    // since the ViewModel is the single source of truth for form text.
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }
    if (amountController.text != formState.amountText) {
      amountController.text = formState.amountText;
    }

    return FormScaffold(
      title: 'Edit Plan',
      canSave: formState.canSave,
      onSave: viewModel.save,
      error: ErrorSection(subject: 'plan', error: formState.error),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: viewModel.setName,
          ),
          const SizedBox(height: 16),
          AmountField(
            controller: amountController,
            allowsNegative: false,
            onChanged: viewModel.setAmount,
          ),
          const SizedBox(height: 16),
          Text('Source: ${formState.sourceName}'),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repeat'),
            trailing: Text(frequencyLabels[formState.frequency]!),
            onTap: viewModel.requestPickRecurrence,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('First date'),
            trailing: Text(formatEntryDate(formState.anchor)),
            onTap: viewModel.requestPickAnchor,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date'),
            value: formState.hasEndDate,
            onChanged: viewModel.setHasEndDate,
          ),
          if (formState.hasEndDate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ends on'),
              trailing: Text(
                formatEntryDate(formState.endDate ?? formState.anchor),
              ),
              onTap: viewModel.requestPickEndDate,
            ),
        ],
      ),
    );
  }
}
