import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/buttons/app_link_button.dart';
import 'package:spendwise/ui/common/lists/section_label.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_edit_draft.dart';
import 'package:spendwise/ui/overview/overview_edit_rows.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/shell/shell_sheet_presentation.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants

const _bodyPadding = EdgeInsets.fromLTRB(16, 4, 16, 16);

const _sectionGap = 14.0;

const _restoreAlignment = Alignment.centerLeft;

const _linkAlignment = Alignment.centerLeft;

// MARK: - Show

Future<void> openEditOverview(BuildContext context) {
  return showAppSheet<void>(
    context,
    presentation: shellSheetPresentation(context),
    presentationResolver: shellSheetPresentation,
    builder: (_) => const EditOverviewSheet(),
  );
}

// MARK: - Sheet

enum _EditOverviewView { edit, add }

class EditOverviewSheet extends ConsumerStatefulWidget {
  const EditOverviewSheet({super.key});

  @override
  ConsumerState<EditOverviewSheet> createState() => _EditOverviewSheetState();
}

class _EditOverviewSheetState extends ConsumerState<EditOverviewSheet> {
  late OverviewEditDraft _draft;
  _EditOverviewView _view = _EditOverviewView.edit;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(displayPreferencesProvider).overviewWidgets;
    _draft = OverviewEditDraft(
      kinds: overviewWidgetsOrDefault(stored),
      cardKinds: overviewCardKinds,
    );
  }

  void _update(OverviewEditDraft next) => setState(() => _draft = next);

  void _show(_EditOverviewView view) => setState(() => _view = view);

  void _done() {
    final current = ref.read(displayPreferencesProvider);
    final notifier = ref.read(displayPreferencesProvider.notifier);
    unawaited(notifier.replace(_draft.applyTo(current)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = _view == _EditOverviewView.edit;
    final done = PrimaryButton(label: overviewEditDone, onPressed: _done);
    final header = AppPickerHeader(
      title: editing ? overviewEditAction : overviewEditAddLabel,
      trailing: done,
    );
    final body = editing
        ? _EditBody(
            draft: _draft,
            onChanged: _update,
            onSeeAll: () => _show(_EditOverviewView.add),
          )
        : _AddBody(draft: _draft, onChanged: _update);
    return AppSheet(
      header: header,
      body: Material(type: MaterialType.transparency, child: body),
    );
  }
}

// MARK: - Edit Body

class _EditBody extends StatelessWidget {
  const _EditBody({
    required this.draft,
    required this.onChanged,
    required this.onSeeAll,
  });

  final OverviewEditDraft draft;
  final ValueChanged<OverviewEditDraft> onChanged;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final intro = Text(
      overviewEditIntro,
      style: context.text.body.copyWith(color: context.colors.subtext),
    );
    final shownLabel = const SectionLabel(overviewEditShownLabel);
    final addable = _AddableSection(draft: draft, onChanged: onChanged);
    final seeAll = Align(
      alignment: _linkAlignment,
      child: AppLinkButton(
        label: overviewEditSeeAll,
        onPressed: onSeeAll,
        color: context.colors.action,
      ),
    );
    final restore = Align(
      alignment: _restoreAlignment,
      child: SecondaryButton(
        label: overviewEditRestore,
        onPressed: () => onChanged(draft.restoreDefault()),
      ),
    );
    return Padding(
      padding: _bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          intro,
          const SizedBox(height: _sectionGap),
          shownLabel,
          _ShownList(draft: draft, onChanged: onChanged),
          addable,
          seeAll,
          restore,
        ],
      ),
    );
  }
}

// MARK: - Shown List

class _ShownList extends StatelessWidget {
  const _ShownList({required this.draft, required this.onChanged});

  final OverviewEditDraft draft;
  final ValueChanged<OverviewEditDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final shown = draft.shown;
    Widget rowAt(BuildContext context, int index) {
      final kind = shown[index];
      return ShownRow(
        key: ValueKey(kind),
        index: index,
        card: overviewCardFor(kind)!,
        onHide: draft.canHide ? () => onChanged(draft.hide(kind)) : null,
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shown.length,
      itemBuilder: rowAt,
      onReorderItem: (from, to) => onChanged(draft.moveShown(from, to)),
    );
  }
}

// MARK: - Addable Section

class _AddableSection extends StatelessWidget {
  const _AddableSection({required this.draft, required this.onChanged});

  final OverviewEditDraft draft;
  final ValueChanged<OverviewEditDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final addable = draft.addable;
    if (addable.isEmpty) return const SizedBox.shrink();

    final rows = [
      for (final kind in addable)
        AddableRow(
          key: ValueKey(kind),
          card: overviewCardFor(kind)!,
          onAdd: () => onChanged(draft.add(kind)),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _sectionGap),
        const SectionLabel(overviewEditAddLabel),
        ...rows,
      ],
    );
  }
}

// MARK: - Add Body

class _AddBody extends StatelessWidget {
  const _AddBody({required this.draft, required this.onChanged});

  final OverviewEditDraft draft;
  final ValueChanged<OverviewEditDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final kind in draft.cardKinds)
        CatalogueRow(
          key: ValueKey(kind),
          card: overviewCardFor(kind)!,
          added: draft.isAdded(kind),
          onAdd: () => onChanged(draft.add(kind)),
        ),
    ];
    return Padding(
      padding: _bodyPadding,
      child: Column(children: rows),
    );
  }
}
