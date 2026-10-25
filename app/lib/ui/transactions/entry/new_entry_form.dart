import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/format/amount_input.dart';
import 'package:spendwise/ui/transactions/entry/add_amount_block.dart';
import 'package:spendwise/ui/transactions/entry/animated_input_surface.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_rows.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_stop_host.dart';
import 'package:spendwise/ui/shell/phone_bar.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Visual Constants

const _desktopMaxHeightFraction = 1.0;

const _sectionGap = 8.0;

const _segmentGap = 2.0;

const _segmentLabelPadding = 2.0;

const _keypadSegmentPadding = 5.0;

// MARK: - NewEntryForm
class NewEntryForm extends StatefulWidget {
  const NewEntryForm({
    super.key,
    required this.formKey,
    required this.viewModel,
    required this.state,
    required this.display,
    this.alert,
    this.onAlertAction,
  });

  final String? formKey;
  final EntryFormViewModel viewModel;
  final EntryFormViewState state;
  final EntryFormDisplay display;

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
  late final _noteController = TextEditingController(
    text: widget.state.noteText,
  );
  final _amountFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _nameGroupId = Object();
  final _noteGroupId = Object();
  bool _keyboardSeen = false;
  bool _padShown = false;
  Offset? _outsideDownAt;

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
    final textFocused = _nameFocus.hasFocus || _noteFocus.hasFocus;
    final restorePad = dismissed && textFocused && _usesPad;
    if (restorePad) _amountFocus.requestFocus();
  }

  void _outsideDown(PointerDownEvent event) => _outsideDownAt = event.position;

  void _outsideUp(FocusNode node, PointerUpEvent event) {
    final down = _outsideDownAt;
    _outsideDownAt = null;
    if (down == null) return;
    if ((event.position - down).distance > kTouchSlop) return;
    node.unfocus();
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
    if (_noteController.text != widget.state.noteText) {
      _noteController.text = widget.state.noteText;
    }
  }

  @override
  void dispose() {
    _amountFocus.removeListener(_refresh);
    _amountFocus.dispose();
    _nameFocus.dispose();
    _noteFocus.dispose();
    _amountController.dispose();
    _nameController.dispose();
    _noteController.dispose();
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
    final presentation =
        AppSheetAlertSlot.maybeOf(context)?.presentation ??
        AppSheetPresentation.phone;
    final desktop = presentation == AppSheetPresentation.desktop;
    final focusedPad = !desktop && _amountFocus.hasFocus;
    final route = ModalRoute.of(context);
    final exiting = route != null && !route.isActive;
    final leaving = exiting || state.dismissed;
    final padVisible = leaving ? _padShown : focusedPad;
    _padShown = padVisible;
    final save = state.canSave ? viewModel.save : null;
    final header = NewEntryHeader(presentation: presentation, onSave: save);
    final body = _NewEntryBody(
      formKey: widget.formKey,
      viewModel: viewModel,
      state: state,
      amountController: _amountController,
      nameController: _nameController,
      amountFocus: _amountFocus,
      nameFocus: _nameFocus,
      nameGroupId: _nameGroupId,
      noteController: _noteController,
      noteFocus: _noteFocus,
      noteGroupId: _noteGroupId,
      systemKeyboard: desktop,
      keypad: padVisible,
      display: widget.display,
      onOutsideDown: _outsideDown,
      onOutsideUp: _outsideUp,
    );
    final pad = padVisible
        ? TextFieldTapRegion(
            child: NumberPad(
              enabled: true,
              onDigit: (digit) => _applyEdit(AmountEdit.insert(digit)),
              onDecimal: () => _applyEdit(const AmountEdit.insert('.')),
              onBackspace: () => _applyEdit(const AmountEdit.delete()),
            ),
          )
        : null;
    Widget sheet(BuildContext context, Widget surface) {
      return AppSheet(
        header: header,
        body: body,
        footer: NewEntrySaveFooter(onSave: save, keypad: padVisible),
        inputSurface: surface,
        dragToDismiss: true,
        variant: AppSheetVariant.form,
        alert: widget.alert,
        onAlertAction: widget.onAlertAction,
        desktopMaxHeightFraction: _desktopMaxHeightFraction,
        phoneBottomClearance: _phoneBottomClearance(context),
      );
    }

    return AnimatedInputSurface(builder: sheet, child: pad);
  }
}

double _phoneBottomClearance(BuildContext context) {
  final phone = ShellLayoutModeScope.maybeOf(context) == ShellLayoutMode.phone;
  final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
  if (!phone || keyboardUp) return 0;
  return phoneBarNavigationHeight(context) +
      MediaQuery.paddingOf(context).bottom;
}

class _NewEntryBody extends ConsumerWidget {
  const _NewEntryBody({
    required this.formKey,
    required this.viewModel,
    required this.state,
    required this.amountController,
    required this.nameController,
    required this.amountFocus,
    required this.nameFocus,
    required this.nameGroupId,
    required this.noteController,
    required this.noteFocus,
    required this.noteGroupId,
    required this.systemKeyboard,
    required this.keypad,
    required this.display,
    required this.onOutsideDown,
    required this.onOutsideUp,
  });

  final String? formKey;
  final EntryFormViewModel viewModel;
  final EntryFormViewState state;
  final TextEditingController amountController;
  final TextEditingController nameController;
  final FocusNode amountFocus;
  final FocusNode nameFocus;
  final Object nameGroupId;
  final TextEditingController noteController;
  final FocusNode noteFocus;
  final Object noteGroupId;
  final bool systemKeyboard;
  final bool keypad;
  final EntryFormDisplay display;
  final ValueChanged<PointerDownEvent> onOutsideDown;
  final void Function(FocusNode, PointerUpEvent) onOutsideUp;

  static const _kindOptions = [
    SegmentedOption(value: EntryFormKind.expense, label: 'Expense'),
    SegmentedOption(value: EntryFormKind.income, label: 'Income'),
    SegmentedOption(value: EntryFormKind.transfer, label: 'Transfer'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptEnabled = ref.watch(scanStripEnabledProvider).value ?? true;
    final kind = SegmentedControl<EntryFormKind>(
      options: _kindOptions,
      value: state.kind,
      onChanged: viewModel.setKind,
      segmentGap: _segmentGap,
      labelHorizontalPadding: _segmentLabelPadding,
      labelVerticalPadding: keypad ? _keypadSegmentPadding : null,
    );
    final amount = AddAmountBlock(
      controller: amountController,
      focusNode: amountFocus,
      kind: state.kind,
      systemKeyboard: systemKeyboard,
      onChanged: viewModel.setAmount,
      onTapOutside: onOutsideDown,
      onTapUpOutside: (event) => onOutsideUp(amountFocus, event),
    );
    final group = NewEntryRows(
      viewModel: viewModel,
      state: state,
      display: display,
      nameController: nameController,
      nameFocus: nameFocus,
      nameGroupId: nameGroupId,
      noteController: noteController,
      noteFocus: noteFocus,
      noteGroupId: noteGroupId,
      keypad: keypad,
      onOutsideDown: onOutsideDown,
      onOutsideUp: onOutsideUp,
      receiptEnabled: receiptEnabled,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        kind,
        const SizedBox(height: _sectionGap),
        amount,
        const SizedBox(height: _sectionGap),
        group,
        ReceiptScanStopHost(formKey: formKey),
      ],
    );
  }
}
