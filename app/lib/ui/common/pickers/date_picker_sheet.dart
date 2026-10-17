import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Show
Future<DateTime?> showDatePickerSheet({
  required BuildContext context,
  required AppSheetPresentation Function(BuildContext) presentation,
  required String title,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showPickerAppSheet<DateTime>(
    context,
    presentation: presentation,
    builder: (_) => DatePickerSheet(
      title: title,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

// MARK: - DatePickerSheet
class DatePickerSheet extends StatefulWidget {
  const DatePickerSheet({
    super.key,
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late DateTime _draft = widget.initialDate;
  int _calendarGeneration = 0;

  bool get _todayInRange {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateUtils.dateOnly(widget.firstDate);
    final last = DateUtils.dateOnly(widget.lastDate);
    return !today.isBefore(first) && !today.isAfter(last);
  }

  void _selectToday() {
    setState(() {
      _draft = DateUtils.dateOnly(DateTime.now());
      _calendarGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = TextButton(
      key: pickerDoneKey,
      onPressed: () => Navigator.of(context).pop(_draft),
      child: const Text('Done'),
    );
    final today = TextButton(
      key: pickerTodayKey,
      onPressed: _todayInRange ? _selectToday : null,
      child: const Text('Today'),
    );
    final calendar = CalendarDatePicker(
      key: ValueKey(_calendarGeneration),
      initialDate: _draft,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      onDateChanged: (value) => _draft = value,
    );

    return AppPickerSheet(
      title: widget.title,
      trailing: done,
      body: calendar,
      footer: Align(alignment: Alignment.centerLeft, child: today),
    );
  }
}
