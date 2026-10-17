import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const pickerCancelKey = ValueKey('picker-cancel');

const pickerNoneKey = ValueKey('picker-none');

const pickerDoneKey = ValueKey('picker-done');

const pickerTodayKey = ValueKey('picker-today');

const _headerPadding = EdgeInsets.only(bottom: 8);

const _titlePadding = EdgeInsets.symmetric(horizontal: 8);

// MARK: - AppPickerSheet
class AppPickerSheet extends StatelessWidget {
  const AppPickerSheet({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.footer,
  });

  final String title;
  final Widget body;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final header = AppPickerHeader(title: title, trailing: trailing);
    return AppSheet(header: header, body: body, footer: footer);
  }
}

// MARK: - AppPickerHeader
class AppPickerHeader extends StatelessWidget {
  const AppPickerHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cancel = TextButton(
      key: pickerCancelKey,
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    );
    final heading = Padding(
      padding: _titlePadding,
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );

    return Padding(
      padding: _headerPadding,
      child: Row(
        children: [
          cancel,
          Expanded(child: heading),
          ?trailing,
        ],
      ),
    );
  }
}
