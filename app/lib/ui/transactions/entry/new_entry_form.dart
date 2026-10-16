import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/format/amount_input.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/entry/add_amount_block.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

// MARK: - Visual Constants

const _actionWidth = double.infinity;

const _loadingIndicatorSize = 36.0;

const _loadingBodySpacing = 24.0;

const _desktopMaxHeightFraction = 1.0;

const _sectionGap = 12.0;

const _amountRegion = 'add-amount';

const _groupRadius = 12.0;

const _groupBorderWidth = 1.0;

const _groupPadding = EdgeInsets.symmetric(horizontal: 10.0);

const _actionPadding = EdgeInsets.symmetric(horizontal: 8.0);

const _actionMinSize = 48.0;

// MARK: - NewEntryForm
class NewEntryForm extends StatefulWidget {
  const NewEntryForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    required this.state,
    this.alert,
    this.onAlertAction,
  });

  final String? formKey;
  final EntryFormViewModel viewModel;
  final EntryFormViewState state;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  @override
  State<NewEntryForm> createState() => _NewEntryFormState();
}

class _NewEntryFormState extends State<NewEntryForm> {
  late final _amountController = TextEditingController(
    text: widget.state.amountText,
  );
  late final _nameController = TextEditingController(
    text: widget.state.nameText,
  );
  final _amountFocus = FocusNode();
  final _nameFocus = FocusNode();
  bool _keyboardSeen = false;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autofocusAmount());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final dismissed = _keyboardSeen && !keyboardUp;
    _keyboardSeen = keyboardUp;
    final restorePad = dismissed && _nameFocus.hasFocus && _usesPad;
    if (restorePad) _amountFocus.requestFocus();
  }

  @override
  void didUpdateWidget(NewEntryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_amountController.text != widget.state.amountText) {
      _amountController.text = widget.state.amountText;
    }
    if (_nameController.text != widget.state.nameText) {
      _nameController.text = widget.state.nameText;
    }
  }

  @override
  void dispose() {
    _amountFocus.removeListener(_refresh);
    _amountFocus.dispose();
    _nameFocus.dispose();
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _usesPad =>
      context
          .getInheritedWidgetOfExactType<AppSheetAlertSlot>()
          ?.presentation !=
      AppSheetPresentation.desktop;

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _autofocusAmount() {
    if (mounted && _usesPad) _amountFocus.requestFocus();
  }

  void _applyEdit(AmountEdit edit) {
    final current = _amountController.value;
    final next = applyAmountEdit(current, edit);
    if (next == current) return;
    _amountController.value = next;
    widget.viewModel.setAmount(next.text);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final state = widget.state;
    final presentation = AppSheetAlertSlot.maybeOf(context)?.presentation;
    final desktop = presentation == AppSheetPresentation.desktop;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final padVisible = !desktop && _amountFocus.hasFocus && !keyboardUp;
    final save = state.canSave ? viewModel.save : null;
    final header = _NewEntryHeader(
      onCancel: viewModel.cancel,
      onSave: desktop ? null : save,
      showSave: !desktop,
    );
    final body = _NewEntryBody(
      formKey: widget.formKey,
      viewModel: viewModel,
      state: state,
      amountController: _amountController,
      nameController: _nameController,
      amountFocus: _amountFocus,
      nameFocus: _nameFocus,
      systemKeyboard: desktop,
    );
    final pad = padVisible
        ? NumberPad(
            enabled: true,
            onDigit: (digit) => _applyEdit(AmountEdit.insert(digit)),
            onDecimal: () => _applyEdit(const AmountEdit.insert('.')),
            onBackspace: () => _applyEdit(const AmountEdit.delete()),
          )
        : null;
    final inputSurface = pad == null
        ? null
        : TapRegion(groupId: _amountRegion, child: pad);

    return AppSheet(
      header: header,
      body: body,
      footer: _NewEntrySaveFooter(onSave: save),
      inputSurface: inputSurface,
      dragToDismiss: true,
      alert: widget.alert,
      onAlertAction: widget.onAlertAction,
      desktopMaxHeightFraction: _desktopMaxHeightFraction,
    );
  }
}

// MARK: - NewEntryBody
class _NewEntryBody extends StatelessWidget {
  const _NewEntryBody({
    required this.formKey,
    required this.viewModel,
    required this.state,
    required this.amountController,
    required this.nameController,
    required this.amountFocus,
    required this.nameFocus,
    required this.systemKeyboard,
  });

  final String? formKey;
  final EntryFormViewModel viewModel;
  final EntryFormViewState state;
  final TextEditingController amountController;
  final TextEditingController nameController;
  final FocusNode amountFocus;
  final FocusNode nameFocus;
  final bool systemKeyboard;

  static const _kindOptions = [
    SegmentedOption(value: EntryFormKind.expense, label: 'Expense'),
    SegmentedOption(value: EntryFormKind.income, label: 'Income'),
    SegmentedOption(value: EntryFormKind.transfer, label: 'Transfer'),
  ];

  @override
  Widget build(BuildContext context) {
    final kind = SegmentedControl<EntryFormKind>(
      options: _kindOptions,
      value: state.kind,
      onChanged: viewModel.setKind,
    );
    final amountBlock = AddAmountBlock(
      controller: amountController,
      focusNode: amountFocus,
      systemKeyboard: systemKeyboard,
      onChanged: viewModel.setAmount,
    );
    final amount = TapRegion(
      groupId: _amountRegion,
      onTapOutside: (_) => amountFocus.unfocus(),
      child: GestureDetector(
        onTap: amountFocus.requestFocus,
        child: amountBlock,
      ),
    );
    final name = TextField(
      controller: nameController,
      focusNode: nameFocus,
      decoration: const InputDecoration(hintText: 'Name'),
      onChanged: viewModel.setName,
      onTapOutside: (_) => nameFocus.unfocus(),
    );
    final rows = EntryFields(
      viewModel: viewModel,
      state: state,
      readOnly: false,
      includeHead: false,
    );
    final group = _FormGroup(children: [name, rows]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kind,
        const SizedBox(height: _sectionGap),
        amount,
        const SizedBox(height: _sectionGap),
        group,
        const SizedBox(height: _sectionGap),
        ReceiptScanStrip(formKey: formKey),
      ],
    );
  }
}

// MARK: - FormGroup
class _FormGroup extends StatelessWidget {
  const _FormGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_groupRadius),
      side: BorderSide(color: colors.edge, width: _groupBorderWidth),
    );

    return Material(
      color: colors.surface,
      shape: shape,
      child: Padding(
        padding: _groupPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

// MARK: - NewEntryLoadingForm
class NewEntryLoadingForm extends StatelessWidget {
  const NewEntryLoadingForm({
    super.key,
    required this.onCancel,
    this.alert,
    this.onAlertAction,
  });

  final VoidCallback? onCancel;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      header: _NewEntryHeader(onCancel: onCancel),
      body: const _NewEntryLoadingBody(),
      footer: const _NewEntrySaveFooter(onSave: null),
      alert: alert,
      onAlertAction: onAlertAction,
      desktopMaxHeightFraction: _desktopMaxHeightFraction,
    );
  }
}

// MARK: - NewEntryLoadingBody
class _NewEntryLoadingBody extends StatelessWidget {
  const _NewEntryLoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _loadingBodySpacing),
        Center(
          child: SizedBox(
            width: _loadingIndicatorSize,
            height: _loadingIndicatorSize,
            child: CircularProgressIndicator(),
          ),
        ),
        SizedBox(height: _loadingBodySpacing),
      ],
    );
  }
}

// MARK: - NewEntryHeader
class _NewEntryHeader extends StatelessWidget {
  const _NewEntryHeader({
    required this.onCancel,
    this.onSave,
    this.showSave = false,
  });

  final VoidCallback? onCancel;

  final Future<void> Function()? onSave;

  final bool showSave;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      padding: _actionPadding,
      minimumSize: const Size(_actionMinSize, _actionMinSize),
    );
    final cancel = Flexible(
      child: TextButton(
        style: style,
        onPressed: onCancel,
        child: const _ActionLabel('Cancel'),
      ),
    );
    final titleText = Text(
      'Add entry',
      maxLines: 1,
      softWrap: false,
      style: Theme.of(context).textTheme.titleMedium,
    );
    final title = FittedBox(fit: BoxFit.scaleDown, child: titleText);
    final saveAction = showSave
        ? Flexible(
            child: TextButton(
              style: style,
              onPressed: onSave,
              child: const _ActionLabel('Save'),
            ),
          )
        : const SizedBox(width: _actionMinSize);

    return Row(
      children: [
        cancel,
        Expanded(child: title),
        saveAction,
      ],
    );
  }
}

// MARK: - ActionLabel
class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, softWrap: false),
    );
  }
}

// MARK: - NewEntrySaveFooter
class _NewEntrySaveFooter extends StatelessWidget {
  const _NewEntrySaveFooter({required this.onSave});

  final Future<void> Function()? onSave;

  static const _saveTopSpacing = 4.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _saveTopSpacing),
      child: SizedBox(
        width: _actionWidth,
        child: FilledButton(onPressed: onSave, child: const Text('Save entry')),
      ),
    );
  }
}
