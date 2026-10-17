import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const pickerDoneKey = ValueKey('picker-done');

const pickerTodayKey = ValueKey('picker-today');

const _headerPadding = EdgeInsets.only(bottom: 8);

const _titleReservedWidth = 112.0;

const _titlePadding = EdgeInsets.symmetric(horizontal: _titleReservedWidth);

// MARK: - Show
Future<T?> showPickerAppSheet<T>(
  BuildContext context, {
  required AppSheetPresentation Function(BuildContext) presentation,
  required WidgetBuilder builder,
}) {
  return showAppSheet<T>(
    context,
    presentation: presentation(context),
    presentationResolver: presentation,
    builder: builder,
  );
}

// MARK: - AppPickerSheet
class AppPickerSheet extends StatelessWidget {
  const AppPickerSheet({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.trailing,
    this.footer,
  });

  final String title;
  final Widget body;
  final Widget? leading;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final header = AppPickerHeader(
      title: title,
      leading: leading,
      trailing: trailing,
    );
    return AppSheet(
      header: header,
      body: body,
      footer: footer,
      dragToDismiss: true,
    );
  }
}

// MARK: - AppPickerHeader
class AppPickerHeader extends StatelessWidget {
  const AppPickerHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      title,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium,
    );
    final heading = Center(
      child: Padding(padding: _titlePadding, child: label),
    );

    final leadingSlot = Align(alignment: Alignment.centerLeft, child: leading);
    final trailingSlot = Align(
      alignment: Alignment.centerRight,
      child: trailing,
    );

    return Padding(
      padding: _headerPadding,
      child: Stack(
        alignment: Alignment.center,
        children: [heading, leadingSlot, trailingSlot],
      ),
    );
  }
}
