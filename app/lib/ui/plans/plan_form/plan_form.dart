import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/ends_choice_sheet.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/form_sheet_load_states.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/plans/plan_form/plan_form_view_model.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';

// MARK: - Constants
const _sheetTitle = 'Edit plan';
const _saveLabel = 'Save plan';
const _retryLabel = 'Try again';
const _nameHint = 'Name';
const _accountLabel = 'Account';
const _repeatLabel = 'Repeat';
const _firstDateLabel = 'First date';
const _endsLabel = 'Ends';
const _endDateLabel = 'End date';
const _neverLabel = 'Never';
const _onADateLabel = 'On a date';
const _loadErrorTitle = "Couldn't load this plan";
const _saveErrorTitle = 'Could not save plan';

const _rowContentPadding = EdgeInsets.zero;
const _fieldGap = 16.0;
const _footerWidth = double.infinity;
const _lockIcon = Icons.lock_outline;
const _lockIconSize = 16.0;
const _lockGap = 6.0;
final _pickerFirstDate = DateTime.utc(2000);
final _pickerLastDate = DateTime.utc(2100);

// MARK: - Sheet Presenter
Future<void> showPlanFormSheet({
  required BuildContext context,
  required String planID,
  required void Function(AppSheetRoute<void>) onRouteCreated,
}) {
  return showAppSheet<void>(
    context,
    presentation: shellSheetPresentation(context),
    presentationResolver: shellSheetPresentation,
    onRouteCreated: onRouteCreated,
    builder: (_) => PlanForm(planId: planID),
  );
}

// MARK: - PlanForm
class PlanForm extends ConsumerStatefulWidget {
  const PlanForm({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanForm> createState() => _PlanFormState();
}

// MARK: - PlanFormState
class _PlanFormState extends ConsumerState<PlanForm> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _amountController = TextEditingController();

  ProviderSubscription<AsyncValue<PlanFormViewState>>? _subscription;
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      planFormViewModelProvider(widget.planId),
      (previous, next) => _handleStep(next.value?.step),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
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

  PlanFormViewState? get _formState =>
      ref.read(planFormViewModelProvider(widget.planId)).value;

  bool get _formIsActive => mounted && (_route?.isActive ?? false);

  void _handleStep(PlanFormStep? step) {
    if (step == null) return;
    _viewModel.clearStep();
    switch (step) {
      case PickRecurrenceRequested():
        _pickRecurrence();
      case PickAnchorRequested():
        _pickAnchor();
      case PickEndDateRequested():
        _pickEndDate();
      case PlanFormSaved():
        _closeOwnRoute();
    }
  }

  void _closeOwnRoute() {
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  Future<void> _pickRecurrence() async {
    final formState = _formState;
    if (formState == null) return;
    final picked = await showRecurrencePickerSheet(
      context: context,
      selected: formState.frequency,
      includesNoRepeat: false,
      sheetPresentation: shellSheetPresentation,
    );
    if (!_formIsActive) return;
    _viewModel.applyPickedRecurrence(picked);
  }

  Future<DateTime?> _chooseDate({
    required String title,
    required DateTime initialDate,
  }) {
    return showDatePickerSheet(
      context: context,
      presentation: shellSheetPresentation,
      title: title,
      initialDate: initialDate,
      firstDate: _pickerFirstDate,
      lastDate: _pickerLastDate,
    );
  }

  Future<void> _pickAnchor() async {
    final formState = _formState;
    if (formState == null) return;
    final picked = await _chooseDate(
      title: _firstDateLabel,
      initialDate: formState.anchor,
    );
    if (!_formIsActive) return;
    _viewModel.applyPickedAnchor(picked);
  }

  Future<void> _pickEndDate() async {
    final formState = _formState;
    if (formState == null) return;
    final picked = await _chooseDate(
      title: _endDateLabel,
      initialDate: formState.endDate ?? formState.anchor,
    );
    if (!_formIsActive) return;
    _viewModel.applyPickedEndDate(picked);
  }

  Future<void> _pickEnds() async {
    final formState = _formState;
    if (formState == null) return;
    final choice = await showEndsChoiceSheet(
      context: context,
      presentation: shellSheetPresentation,
      hasEndDate: formState.hasEndDate,
    );
    if (!_formIsActive || choice == null) return;
    _viewModel.setHasEndDate(choice == EndsChoice.chooseDate);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(planFormViewModelProvider(widget.planId));
    final formState = asyncState.value;
    if (formState != null) {
      return _PlanFormBody(
        formState: formState,
        viewModel: _viewModel,
        nameController: _nameController,
        amountController: _amountController,
        onPickEnds: _pickEnds,
      );
    }
    final error = asyncState.error;
    if (error == null) return const FormSheetLoading(title: _sheetTitle);
    final provider = planFormViewModelProvider(widget.planId);
    final retry = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(
        label: _retryLabel,
        onPressed: () => ref.invalidate(provider),
      ),
    );
    return FormSheetLoadError(
      title: _sheetTitle,
      message: _loadErrorTitle,
      error: error,
      footer: retry,
    );
  }
}

// MARK: - PlanFormBody
class _PlanFormBody extends StatelessWidget {
  const _PlanFormBody({
    required this.formState,
    required this.viewModel,
    required this.nameController,
    required this.amountController,
    required this.onPickEnds,
  });

  final PlanFormViewState formState;
  final PlanFormViewModel viewModel;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final VoidCallback onPickEnds;

  @override
  Widget build(BuildContext context) {
    if (nameController.text != formState.name) {
      nameController.text = formState.name;
    }
    if (amountController.text != formState.amountText) {
      amountController.text = formState.amountText;
    }

    final name = TextField(
      controller: nameController,
      decoration: const InputDecoration(hintText: _nameHint),
      onChanged: viewModel.setName,
    );
    final amount = AmountField(
      controller: amountController,
      allowsNegative: false,
      onChanged: viewModel.setAmount,
    );
    final account = _FormRow(
      label: _accountLabel,
      trailing: _LockedValue(value: formState.sourceName),
    );
    final repeat = _FormRow(
      label: _repeatLabel,
      trailing: Text(addFrequencyLabels[formState.frequency]!),
      onTap: viewModel.requestPickRecurrence,
    );
    final firstDate = _FormRow(
      label: _firstDateLabel,
      trailing: Text(formatEntryDate(formState.anchor)),
      onTap: viewModel.requestPickAnchor,
    );
    final ends = _FormRow(
      label: _endsLabel,
      trailing: Text(formState.hasEndDate ? _onADateLabel : _neverLabel),
      onTap: onPickEnds,
    );
    final endDate = _FormRow(
      label: _endDateLabel,
      trailing: Text(formatEntryDate(formState.endDate ?? formState.anchor)),
      onTap: viewModel.requestPickEndDate,
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        name,
        const SizedBox(height: _fieldGap),
        amount,
        const SizedBox(height: _fieldGap),
        account,
        repeat,
        firstDate,
        ends,
        if (formState.hasEndDate) endDate,
      ],
    );
    final save = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(
        label: _saveLabel,
        onPressed: formState.canSave ? viewModel.save : null,
      ),
    );
    final saveError = formState.error;
    final alert = saveError == null
        ? null
        : SheetAlertData(
            message:
                '$_saveErrorTitle\n${friendlyLedgerErrorMessage(saveError)}',
            severity: SheetAlertSeverity.error,
          );

    return AppSheet(
      header: const AppPickerHeader(title: _sheetTitle),
      body: body,
      footer: save,
      alert: alert,
      dragToDismiss: true,
      variant: AppSheetVariant.form,
    );
  }
}

// MARK: - FormRow
class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.trailing, this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: _rowContentPadding,
        title: Text(label),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

// MARK: - LockedValue
class _LockedValue extends StatelessWidget {
  const _LockedValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(_lockIcon, size: _lockIconSize),
        const SizedBox(width: _lockGap),
        Text(value),
      ],
    );
  }
}
