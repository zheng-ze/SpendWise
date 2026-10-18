import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/recurrence_picker.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/entry/add_entry_row.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

// MARK: - Visual Constants

const _groupRadius = 14.0;

const _groupBorderWidth = 1.0;

const _groupPadding = EdgeInsets.symmetric(horizontal: 10.0);

const _focusedUnderlineHeight = 2.0;

const _hintSize = 10.0;

const _hintLineHeight = 1.4;

const _hintPadding = EdgeInsets.only(top: 5.0, bottom: 4.0);

const _switchTapTarget = MaterialTapTargetSize.shrinkWrap;

// MARK: - Copy

const _chooseCategoryLabel = 'Choose';

const _selectAccountLabel = 'Select';

const _neverEndsLabel = 'Never';

const _recurringHint = 'Saving creates a plan. Review it in Money, Plans.';

// MARK: - NewEntryRows
class NewEntryRows extends StatelessWidget {
  const NewEntryRows({
    super.key,
    required this.viewModel,
    required this.state,
    required this.display,
    required this.nameController,
    required this.nameFocus,
    required this.nameGroupId,
    required this.noteController,
    required this.noteFocus,
    required this.noteGroupId,
    required this.keypad,
    required this.onOutsideDown,
    required this.onOutsideUp,
  });

  final EntryFormViewModel viewModel;
  final EntryFormViewState state;
  final EntryFormDisplay display;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final Object nameGroupId;
  final TextEditingController noteController;
  final FocusNode noteFocus;
  final Object noteGroupId;
  final bool keypad;
  final ValueChanged<PointerDownEvent> onOutsideDown;
  final void Function(FocusNode, PointerUpEvent) onOutsideUp;

  @override
  Widget build(BuildContext context) {
    final transfer = state.kind == EntryFormKind.transfer;
    final recurrence = state.recurrence;
    final endDate = state.endDate;

    void open(VoidCallback request) {
      FocusManager.instance.primaryFocus?.unfocus();
      request();
    }

    _PickerRow picker(
      String key,
      String label,
      String value,
      VoidCallback request,
    ) => _PickerRow(
      key: ValueKey('new-entry-$key'),
      label: label,
      value: value,
      keypad: keypad,
      onTap: () => open(request),
    );

    _InlineTextRow textRow(
      String key,
      String label,
      TextEditingController controller,
      FocusNode focusNode,
      Object groupId,
      ValueChanged<String> onChanged,
      TextInputType keyboardType,
    ) => _InlineTextRow(
      fieldKey: ValueKey('new-entry-$key'),
      label: label,
      controller: controller,
      focusNode: focusNode,
      groupId: groupId,
      keyboardType: keyboardType,
      keypad: keypad,
      onChanged: onChanged,
      onOutsideDown: onOutsideDown,
      onOutsideUp: onOutsideUp,
    );

    final nameRow = textRow(
      'name',
      'Name',
      nameController,
      nameFocus,
      nameGroupId,
      viewModel.setName,
      TextInputType.text,
    );
    final noteRow = textRow(
      'note',
      'Note',
      noteController,
      noteFocus,
      noteGroupId,
      viewModel.setNote,
      TextInputType.multiline,
    );
    final analysisSwitch = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Switch(
        value: state.includeInAnalysis,
        materialTapTargetSize: _switchTapTarget,
        onChanged: viewModel.setIncludeInAnalysis,
      ),
    );
    final rows = <Widget>[
      nameRow,
      if (transfer)
        picker(
          'from',
          'From',
          display.sourceLabel ?? _selectAccountLabel,
          viewModel.requestPickSource,
        )
      else
        picker(
          'category',
          'Category',
          display.categoryLabel ?? _chooseCategoryLabel,
          viewModel.requestPickCategory,
        ),
      if (transfer)
        picker(
          'to',
          'To',
          display.destinationLabel ?? _selectAccountLabel,
          viewModel.requestPickDestination,
        )
      else
        picker(
          'account',
          'Account',
          display.sourceLabel ?? _selectAccountLabel,
          viewModel.requestPickSource,
        ),
      picker(
        'date',
        'Date',
        formatEntryDate(state.date),
        viewModel.requestPickDate,
      ),
      picker(
        'repeat',
        'Repeat',
        recurrence == null ? addNoRepeatLabel : addFrequencyLabels[recurrence]!,
        viewModel.requestPickRecurrence,
      ),
      if (recurrence != null)
        picker(
          'ends',
          'Ends',
          state.hasEndDate && endDate != null
              ? formatEntryDate(endDate)
              : _neverEndsLabel,
          viewModel.requestPickEnds,
        ),
      noteRow,
      AddEntryRow(
        key: const ValueKey('new-entry-analysis'),
        label: 'Include in analysis',
        value: analysisSwitch,
        keypad: keypad,
        onTap: () => viewModel.setIncludeInAnalysis(!state.includeInAnalysis),
      ),
    ];

    final underlined = {nameRow: nameFocus, noteRow: noteFocus};
    final children = <Widget>[];
    for (final row in rows) {
      final above = children.isEmpty ? null : underlined[children.last];
      if (children.isNotEmpty) {
        children.add(
          above == null
              ? const EntryRowDivider()
              : _FocusDivider(focusNode: above),
        );
      }
      children.add(row);
    }
    if (recurrence != null) children.add(const _RecurringHint());

    return _FormGroup(children: children);
  }
}

// MARK: - InlineTextRow
class _InlineTextRow extends StatelessWidget {
  const _InlineTextRow({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.groupId,
    required this.keyboardType,
    required this.keypad,
    required this.onChanged,
    required this.onOutsideDown,
    required this.onOutsideUp,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Object groupId;
  final TextInputType keyboardType;
  final bool keypad;
  final ValueChanged<String> onChanged;
  final ValueChanged<PointerDownEvent> onOutsideDown;
  final void Function(FocusNode, PointerUpEvent) onOutsideUp;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      groupId: groupId,
      textAlign: TextAlign.end,
      keyboardType: keyboardType,
      maxLines: null,
      style: addRowValueStyle(context),
      cursorColor: context.colors.focus,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onChanged: onChanged,
      onTapOutside: onOutsideDown,
      onTapUpOutside: (event) => onOutsideUp(focusNode, event),
    );
    return TextFieldTapRegion(
      groupId: groupId,
      child: AddEntryRow(
        label: label,
        value: field,
        keypad: keypad,
        onTap: () {
          if (!focusNode.hasFocus) focusNode.requestFocus();
        },
      ),
    );
  }
}

// MARK: - PickerRow
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.keypad,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool keypad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AddEntryRow(
      label: label,
      value: Text(value, textAlign: TextAlign.end),
      keypad: keypad,
      chevron: true,
      onTap: onTap,
    );
  }
}

// MARK: - FocusDivider
class _FocusDivider extends StatelessWidget {
  const _FocusDivider({required this.focusNode});

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final focusColor = context.colors.focus;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        if (!focusNode.hasFocus) return const EntryRowDivider();
        return Container(height: _focusedUnderlineHeight, color: focusColor);
      },
    );
  }
}

// MARK: - RecurringHint
class _RecurringHint extends StatelessWidget {
  const _RecurringHint();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: _hintSize,
      height: _hintLineHeight,
      color: context.colors.subtext,
    );
    return Padding(
      padding: _hintPadding,
      child: Text(_recurringHint, style: style),
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
      clipBehavior: Clip.antiAlias,
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
