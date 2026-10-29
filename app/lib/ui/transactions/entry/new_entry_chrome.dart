import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';

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

// MARK: - NewEntryHeader
class NewEntryHeader extends StatelessWidget {
  const NewEntryHeader({super.key, required this.presentation, this.onSave});

  final AppSheetPresentation presentation;

  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    final title = Text(
      'Add entry',
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
        child: Center(child: title),
      );
    }
    final save = _SideAction(label: 'Save', onPressed: onSave);

    return Row(
      children: [
        const SizedBox(width: _sideColumnWidth),
        Expanded(child: title),
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
    required this.onSave,
    required this.keypad,
  });

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
      child: const Text('Save entry'),
    );

    return Padding(
      padding: const EdgeInsets.only(top: _saveTopSpacing),
      child: SizedBox(width: double.infinity, child: button),
    );
  }
}

// MARK: - NewEntryLoadingForm
class NewEntryLoadingForm extends StatelessWidget {
  const NewEntryLoadingForm({super.key, this.alert, this.onAlertAction});

  final SheetAlertData? alert;

  final VoidCallback? onAlertAction;

  @override
  Widget build(BuildContext context) {
    final presentation = AppSheetAlertSlot.maybeOf(context)?.presentation;
    final header = NewEntryHeader(
      presentation: presentation ?? AppSheetPresentation.phone,
    );

    return AppSheet(
      header: header,
      body: const _NewEntryLoadingBody(),
      footer: const NewEntrySaveFooter(onSave: null, keypad: false),
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
