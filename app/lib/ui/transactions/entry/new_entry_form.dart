import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/format/amount_input.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/entry/add_amount_block.dart';
import 'package:spendwise/ui/transactions/entry/animated_input_surface.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

// MARK: - Visual Constants

const _desktopMaxHeightFraction = 1.0;

const _sectionGap = 8.0;

const _grownHeightFraction = 1.0;

const _groupRadius = 14.0;

const _groupBorderWidth = 1.0;

const _groupPadding = EdgeInsets.symmetric(horizontal: 10.0);

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
    this.display,
    this.alert,
    this.onAlertAction,
  });

  final String? formKey;
  final EntryFormViewModel viewModel;
  final EntryFormViewState state;
  final EntryFormDisplay? display;

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
  bool _routeWasCurrent = true;
  bool _padShown = false;
  Offset? _outsideDownAt;
  FocusNode? _focusAtPointerDown;
  FocusNode? _focusBeforeCover;

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
    _trackCover(ModalRoute.isCurrentOf(context) ?? true);
  }

  void _trackCover(bool current) {
    if (_routeWasCurrent && !current) _focusBeforeCover = _focusAtPointerDown;
    if (!_routeWasCurrent && current) _restoreFocusAfterCover();
    _routeWasCurrent = current;
  }

  void _restoreFocusAfterCover() {
    final node = _focusBeforeCover;
    _focusBeforeCover = null;
    if (node == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });
  }

  void _rememberFocus(PointerDownEvent event) {
    _focusAtPointerDown = _amountFocus.hasFocus
        ? _amountFocus
        : _nameFocus.hasFocus
        ? _nameFocus
        : null;
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
    final presentation =
        AppSheetAlertSlot.maybeOf(context)?.presentation ??
        AppSheetPresentation.phone;
    final desktop = presentation == AppSheetPresentation.desktop;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final focusedPad = !desktop && _amountFocus.hasFocus;
    final route = ModalRoute.of(context);
    final exiting = route != null && !route.isActive;
    final leaving = exiting || state.dismissed;
    final padVisible = leaving ? _padShown : focusedPad;
    _padShown = padVisible;
    final grown = padVisible || _nameFocus.hasFocus || keyboardUp;
    final save = state.canSave ? viewModel.save : null;
    final header = NewEntryHeader(
      presentation: presentation,
      onCancel: viewModel.cancel,
      onSave: save,
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
      keypad: padVisible,
      display: widget.display,
      onOutsideDown: _outsideDown,
      onOutsideUp: _outsideUp,
    );
    final trackedBody = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _rememberFocus,
      child: body,
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
    Widget sheet(BuildContext context, Widget surface, double growth) {
      final fraction = lerpDouble(
        AppSheet.defaultMaxHeightFraction,
        _grownHeightFraction,
        growth,
      );
      return AppSheet(
        header: header,
        body: trackedBody,
        footer: NewEntrySaveFooter(onSave: save, keypad: padVisible),
        inputSurface: surface,
        dragToDismiss: true,
        variant: AppSheetVariant.form,
        alert: widget.alert,
        onAlertAction: widget.onAlertAction,
        desktopMaxHeightFraction: _desktopMaxHeightFraction,
        phoneMaxHeightFraction: fraction!,
      );
    }

    return AnimatedInputSurface(grown: grown, builder: sheet, child: pad);
  }
}

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
  final bool systemKeyboard;
  final bool keypad;
  final EntryFormDisplay? display;
  final ValueChanged<PointerDownEvent> onOutsideDown;
  final void Function(FocusNode, PointerUpEvent) onOutsideUp;

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
    final name = TextField(
      controller: nameController,
      focusNode: nameFocus,
      decoration: const InputDecoration(
        hintText: 'Name',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onChanged: viewModel.setName,
      onTapOutside: onOutsideDown,
      onTapUpOutside: (event) => onOutsideUp(nameFocus, event),
    );
    final rows = EntryFields(
      viewModel: viewModel,
      state: state,
      readOnly: false,
      includeHead: false,
      display: display,
    );
    final group = _FormGroup(children: [name, const EntryRowDivider(), rows]);

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
