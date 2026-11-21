import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:domain/domain.dart' show Account;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/theme/edge_border.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _noPadding = EdgeInsets.zero;
const _firstDay = Account.minStatementDay;
const _lastDay = Account.maxStatementDay;
const _sheetTitle = 'Statement day';
const _maxDigits = 2;
const _doneLabel = 'Done';
const _rowHeight = 48.0;
const _visibleRows = 5;
const _selectionRadius = 14.0;
const _dayFontSize = 20.0;
const _wheelPadding = EdgeInsets.symmetric(horizontal: 16);
const _fieldBorderWidth = 2.0;
const _editIconSize = 20.0;
const _editTapTarget = 48.0;
const _fullWidth = double.infinity;
const _maxWheelShare = 0.4;
const _editLabel = 'Type the day';
const _fieldLabel = 'Statement day, $_firstDay to $_lastDay';
const _invalidHint = 'Enter a day from $_firstDay to $_lastDay';
const _wheelDragDevices = {
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.trackpad,
};

int? parseStatementDay(String text) {
  final day = int.tryParse(text);
  if (day == null || day < _firstDay || day > _lastDay) return null;
  return day;
}

// MARK: - StatementDayPicker
class StatementDayPicker extends StatelessWidget {
  const StatementDayPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.sheetPresentation,
  });

  final int? selected;
  final ValueChanged<int> onSelected;

  final AppSheetPresentation Function(BuildContext)? sheetPresentation;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: _noPadding,
        title: const Text('Statement Day'),
        trailing: Text(selected?.toString() ?? 'Select'),
        onTap: () => _pick(context),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showPickerAppSheet<int>(
      context,
      presentation: sheetPresentation,
      builder: (_) => _StatementDaySheet(initialDay: selected ?? _firstDay),
    );
    if (!context.mounted || chosen == null) return;
    onSelected(chosen);
  }
}

class _StatementDaySheet extends StatefulWidget {
  const _StatementDaySheet({required this.initialDay});

  final int initialDay;

  @override
  State<_StatementDaySheet> createState() => _StatementDaySheetState();
}

class _StatementDaySheetState extends State<_StatementDaySheet> {
  late final FixedExtentScrollController _wheel = FixedExtentScrollController(
    initialItem: widget.initialDay - _firstDay,
  );
  late final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();
  late int _day = widget.initialDay;
  bool _editing = false;

  bool get _valid => !_editing || parseStatementDay(_field.text) != null;

  @override
  void dispose() {
    _wheel.dispose();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (_editing) {
      _focus.requestFocus();
      return;
    }
    _field.text = '$_day';
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _stopEditing() {
    if (!_editing) return;
    setState(() => _editing = false);
  }

  void _onTyped(String text) {
    final day = parseStatementDay(text);
    if (day != null) {
      _day = day;
      _wheel.jumpToItem(day - _firstDay);
    }
    setState(() {});
  }

  bool _onScroll(ScrollStartNotification notification) {
    if (notification.dragDetails != null) _stopEditing();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final done = TextButton(
      key: pickerDoneKey,
      onPressed: _valid ? () => Navigator.of(context).pop(_day) : null,
      child: const Text(_doneLabel),
    );
    final scaledRow = MediaQuery.textScalerOf(context).scale(_rowHeight);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final fitExtent = screenHeight * _maxWheelShare / _visibleRows;
    final itemExtent = math.max(_rowHeight, math.min(scaledRow, fitExtent));
    final wheel = _DayWheel(
      controller: _wheel,
      itemExtent: itemExtent,
      onChanged: (day) => _day = day,
      onScrollStart: _onScroll,
      onPointerDown: _stopEditing,
    );
    final field = _DayField(
      controller: _field,
      focusNode: _focus,
      valid: _valid,
      onDragStart: _stopEditing,
      onChanged: _onTyped,
    );
    final pencil = Align(
      alignment: Alignment.centerRight,
      child: _EditButton(onPressed: _startEditing),
    );
    final fieldRow = SizedBox(height: itemExtent, child: field);
    final stack = Stack(
      alignment: Alignment.center,
      children: [
        _SelectionHighlight(height: itemExtent),
        wheel,
        if (_editing) fieldRow,
        pencil,
      ],
    );
    final height = itemExtent * _visibleRows;

    return AppPickerSheet(
      title: _sheetTitle,
      trailing: done,
      body: Padding(
        padding: _wheelPadding,
        child: SizedBox(height: height, child: stack),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.edit,
      size: _editIconSize,
      color: context.colors.subtext,
    );
    final button = IconButton(
      onPressed: onPressed,
      icon: icon,
      padding: _noPadding,
      constraints: const BoxConstraints.tightFor(
        width: _editTapTarget,
        height: _editTapTarget,
      ),
    );

    return Semantics(
      label: _editLabel,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: button,
    );
  }
}

class _SelectionHighlight extends StatelessWidget {
  const _SelectionHighlight({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final decoration = BoxDecoration(
      color: colors.interactionSurface,
      borderRadius: BorderRadius.circular(_selectionRadius),
      border: fullEdgeBorder(colors),
    );
    return SizedBox(
      width: _fullWidth,
      height: height,
      child: DecoratedBox(decoration: decoration),
    );
  }
}

class _DayWheel extends StatelessWidget {
  const _DayWheel({
    required this.controller,
    required this.itemExtent,
    required this.onChanged,
    required this.onScrollStart,
    required this.onPointerDown,
  });

  final FixedExtentScrollController controller;
  final double itemExtent;
  final ValueChanged<int> onChanged;
  final bool Function(ScrollStartNotification) onScrollStart;
  final VoidCallback onPointerDown;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: context.colors.text,
      fontSize: _dayFontSize,
      fontWeight: SpendWiseText.semibold,
    );
    final picker = CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: itemExtent,
      selectionOverlay: null,
      onSelectedItemChanged: (index) => onChanged(index + _firstDay),
      childCount: _lastDay - _firstDay + 1,
      itemBuilder: (_, index) =>
          Center(child: Text('${index + _firstDay}', style: style)),
    );
    final behavior = ScrollConfiguration.of(context)
        .copyWith(dragDevices: _wheelDragDevices);

    return Listener(
      onPointerDown: (_) => onPointerDown(),
      child: NotificationListener<ScrollStartNotification>(
        onNotification: onScrollStart,
        child: ScrollConfiguration(behavior: behavior, child: picker),
      ),
    );
  }
}

class _DayField extends StatelessWidget {
  const _DayField({
    required this.controller,
    required this.focusNode,
    required this.valid,
    required this.onDragStart,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool valid;
  final VoidCallback onDragStart;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_selectionRadius);
    final errorBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.error, width: _fieldBorderWidth),
    );
    final bandBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: edgeSide(colors),
    );
    final border = valid ? bandBorder : errorBorder;
    final style = TextStyle(
      color: valid ? colors.text : colors.error,
      fontSize: _dayFontSize,
      fontWeight: SpendWiseText.semibold,
    );
    final decoration = InputDecoration(
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      contentPadding: _noPadding,
      filled: true,
      fillColor: colors.interactionSurface,
    );

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_maxDigits),
      ],
      style: style,
      decoration: decoration,
      onChanged: onChanged,
    );
    final semantic = Semantics(
      label: _fieldLabel,
      hint: valid ? null : _invalidHint,
      child: field,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) => onDragStart(),
      child: semantic,
    );
  }
}
