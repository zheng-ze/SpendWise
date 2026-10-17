import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - Constants
const pickerDoneKey = ValueKey('picker-done');

const pickerTodayKey = ValueKey('picker-today');

const _headerPadding = EdgeInsets.only(bottom: 8);

const _headerHeight = kMinInteractiveDimension;

const _titleSpacing = 8.0;

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
  });

  final String title;
  final Widget body;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final header = AppPickerHeader(
      title: title,
      leading: leading,
      trailing: trailing,
    );
    return AppSheet(header: header, body: body, dragToDismiss: true);
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium,
    );
    final height = MediaQuery.textScalerOf(context).scale(_headerHeight);

    return Padding(
      padding: _headerPadding,
      child: SizedBox(
        height: height,
        child: NavigationToolbar(
          leading: leading,
          middle: label,
          trailing: trailing,
          middleSpacing: _titleSpacing,
        ),
      ),
    );
  }
}
