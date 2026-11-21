import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/entry/entry_pane_layout.dart';

// MARK: - Visual Constants

const _sideColumnWidth = 52.0;

const _actionMinHeight = 48.0;

const _saveRadius = 10.0;

const _saveHorizontalPadding = 12.0;

const _saveVerticalPadding = 10.0;

const _saveKeypadVerticalPadding = 8.0;

const _saveTopSpacing = 4.0;

const _loadingIndicatorSize = 36.0;

const _loadingBodySpacing = 24.0;

const addEntryTitle = 'Add entry';

const editEntryTitle = 'Edit entry';

const addActionLabel = 'Save';

const editActionLabel = 'Update';

const addFooterLabel = 'Save entry';

const editFooterLabel = 'Update entry';

// MARK: - EntryFormFrame
enum EntryFormFrame { sheet, pane }

AppSheetPresentation entryFormPresentation(
  BuildContext context,
  EntryFormFrame frame,
) {
  if (frame == EntryFormFrame.pane) return shellSheetPresentation(context);

  return AppSheetAlertSlot.maybeOf(context)?.presentation ??
      AppSheetPresentation.phone;
}

// MARK: - NewEntryHeader
class NewEntryHeader extends StatelessWidget {
  const NewEntryHeader({
    super.key,
    required this.presentation,
    required this.title,
    required this.actionLabel,
    this.onSave,
  });

  final AppSheetPresentation presentation;

  final String title;

  final String actionLabel;

  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    final open = presentation == AppSheetPresentation.open;
    final save = _SideAction(label: actionLabel, onPressed: onSave);

    return AppPickerHeader(title: title, trailing: open ? save : null);
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({required this.label, required this.onPressed});

  final String label;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(_sideColumnWidth, _actionMinHeight),
      textStyle: appActionLabelStyle,
    );

    return TextButton(style: style, onPressed: onPressed, child: Text(label));
  }
}

// MARK: - NewEntrySaveFooter
class NewEntrySaveFooter extends StatelessWidget {
  const NewEntrySaveFooter({
    super.key,
    required this.label,
    required this.onSave,
    required this.keypad,
  });

  final String label;

  final Future<void> Function()? onSave;

  final bool keypad;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: Size.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_saveRadius),
      ),
      padding: EdgeInsets.symmetric(
        vertical: keypad ? _saveKeypadVerticalPadding : _saveVerticalPadding,
        horizontal: _saveHorizontalPadding,
      ),
      textStyle: Theme.of(context).textTheme.labelLarge?.merge(
        context.text.body.copyWith(fontWeight: SpendWiseText.semibold),
      ),
    );
    final button = FilledButton(
      style: style,
      onPressed: onSave,
      child: Text(label),
    );

    return Padding(
      padding: const EdgeInsets.only(top: _saveTopSpacing),
      child: SizedBox(width: double.infinity, child: button),
    );
  }
}

// MARK: - NewEntryLoadingForm
class NewEntryLoadingForm extends StatelessWidget {
  const NewEntryLoadingForm({
    super.key,
    this.frame = EntryFormFrame.sheet,
    this.title = addEntryTitle,
    this.alert,
    this.onAlertAction,
  });

  final EntryFormFrame frame;

  final String title;

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  @override
  Widget build(BuildContext context) {
    final editing = title == editEntryTitle;
    final footer = NewEntrySaveFooter(
      label: editing ? editFooterLabel : addFooterLabel,
      onSave: null,
      keypad: false,
    );
    const body = _NewEntryLoadingBody();
    if (frame == EntryFormFrame.pane) {
      return EntryPaneLayout(
        body: body,
        footer: footer,
        alert: alert,
        onAlertAction: onAlertAction,
      );
    }
    final header = NewEntryHeader(
      presentation: entryFormPresentation(context, frame),
      title: title,
      actionLabel: editing ? editActionLabel : addActionLabel,
    );

    return AppSheet(
      header: header,
      body: body,
      footer: footer,
      variant: AppSheetVariant.form,
      alert: alert,
      onAlertAction: onAlertAction,
    );
  }
}

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
