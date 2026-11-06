import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/transactions/entry/entry_pane_layout.dart';

// MARK: - Visual Constants

const _titleSize = 18.0;

const _titleLineHeight = 1.2;

const _titleWeight = FontWeight.w600;

const _actionSize = 12.0;

const _actionWeight = FontWeight.w600;

const _sideColumnWidth = 52.0;

const _headerMinHeight = 48.0;

const _actionMinHeight = 48.0;

const _saveRadius = 10.0;

const _saveLabelSize = 12.0;

const _saveLabelWeight = FontWeight.w600;

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
    final base = Theme.of(context).textTheme.titleMedium;
    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      style: base?.copyWith(
        fontSize: _titleSize,
        fontWeight: _titleWeight,
        height: _titleLineHeight,
      ),
    );
    const bounds = BoxConstraints(minHeight: _headerMinHeight);
    if (presentation != AppSheetPresentation.open) {
      return ConstrainedBox(
        constraints: bounds,
        child: Center(child: titleText),
      );
    }
    final save = _SideAction(label: actionLabel, onPressed: onSave);

    return Row(
      children: [
        const SizedBox(width: _sideColumnWidth),
        Expanded(child: titleText),
        SizedBox(width: _sideColumnWidth, child: save),
      ],
    );
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
      textStyle: const TextStyle(
        fontSize: _actionSize,
        fontWeight: _actionWeight,
      ),
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
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: _saveLabelSize, fontWeight: _saveLabelWeight),
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
      dragToDismiss: true,
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
