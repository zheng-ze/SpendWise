import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/error_section.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/inputs/form_section_card.dart';
import 'package:spendwise/ui/common/inputs/form_sheet_row.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/ends_choice_sheet.dart';
import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/form_sheet_load_states.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/common/sheets/sheet_session.dart';
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

const _fieldGap = 16.0;
const _footerWidth = double.infinity;
const _lockIcon = Icons.lock_outline;
const _lockIconSize = 16.0;
const _lockGap = 6.0;
const _lockedAccountMaxWidth = 200.0;
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
    builder: (_) => PlanForm(planID: planID),
  );
}

// MARK: - PlanForm
class PlanForm extends ConsumerStatefulWidget {
  const PlanForm({super.key, required this.planID});

  final String planID;

  @override
  ConsumerState<PlanForm> createState() => _PlanFormState();
}

// MARK: - PlanFormState
class _PlanFormState extends ConsumerState<PlanForm> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _amountController = TextEditingController();

  late final _provider = planFormViewModelProvider(widget.planID);

  ProviderSubscription<AsyncValue<PlanFormViewState>>? _subscription;
  ModalRoute<Object?>? _route;
  final List<ModalRoute<dynamic>> _pickerRoutes = [];

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      _provider,
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
    _closePickers();
    _subscription?.close();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  PlanFormViewModel get _viewModel => ref.read(_provider.notifier);

  PlanFormViewState? get _formState => ref.read(_provider).value;

  bool get _formIsActive => mounted && (_route?.isActive ?? false);

  void _trackPicker(ModalRoute<dynamic> route) => _pickerRoutes.add(route);

  // The removal waits for the frame end so it never runs while the tree is being finalized.
  void _closePickers() {
    final routes = List.of(_pickerRoutes);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final route in routes) {
        dismissSheetRoute(route);
      }
    });
  }

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
        dismissSheetRoute(_route);
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
      onRouteCreated: _trackPicker,
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
      onRouteCreated: _trackPicker,
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
      onRouteCreated: _trackPicker,
    );
    if (!_formIsActive || choice == null) return;
    _viewModel.setHasEndDate(choice == EndsChoice.chooseDate);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(_provider);
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
    final retry = SizedBox(
      width: _footerWidth,
      child: PrimaryButton(
        label: _retryLabel,
        onPressed: () => ref.invalidate(_provider),
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
    final lockedAccountName = Text(
      formState.sourceName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final lockedAccountRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(_lockIcon, size: _lockIconSize),
        const SizedBox(width: _lockGap),
        Flexible(child: lockedAccountName),
      ],
    );
    final lockedAccount = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _lockedAccountMaxWidth),
      child: lockedAccountRow,
    );
    final account = FormSheetRow(label: _accountLabel, trailing: lockedAccount);
    final repeat = FormSheetRow(
      label: _repeatLabel,
      trailing: Text(addFrequencyLabels[formState.frequency]!),
      onTap: viewModel.requestPickRecurrence,
    );
    final firstDate = FormSheetRow(
      label: _firstDateLabel,
      trailing: Text(formatEntryDate(formState.anchor)),
      onTap: viewModel.requestPickAnchor,
    );
    final ends = FormSheetRow(
      label: _endsLabel,
      trailing: Text(formState.hasEndDate ? _onADateLabel : _neverLabel),
      onTap: onPickEnds,
    );
    final endDate = FormSheetRow(
      label: _endDateLabel,
      trailing: Text(formatEntryDate(formState.endDate ?? formState.anchor)),
      onTap: viewModel.requestPickEndDate,
    );
    final body = FormSectionCard(
      padding: FormSectionCard.fieldsPadding,
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
