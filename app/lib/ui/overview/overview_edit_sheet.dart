import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
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

const _dragElevation = 6.0;

const _dragRadius = BorderRadius.all(Radius.circular(12));

const _hiddenHeaderKey = ValueKey('overview-edit-hidden-header');

const _hiddenHintKey = ValueKey('overview-edit-hidden-hint');

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

class EditOverviewSheet extends ConsumerStatefulWidget {
  const EditOverviewSheet({super.key});

  @override
  ConsumerState<EditOverviewSheet> createState() => _EditOverviewSheetState();
}

class _EditOverviewSheetState extends ConsumerState<EditOverviewSheet> {
  late OverviewEditDraft _draft;

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

  void _done() {
    final current = ref.read(displayPreferencesProvider);
    final notifier = ref.read(displayPreferencesProvider.notifier);
    unawaited(notifier.replace(_draft.applyTo(current)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final done = PrimaryButton(
      label: overviewEditDone,
      onPressed: _draft.canApply ? _done : null,
    );
    final header = AppPickerHeader(title: overviewEditAction, trailing: done);
    final body = _EditBody(draft: _draft, onChanged: _update);
    return AppSheet(
      header: header,
      body: Material(type: MaterialType.transparency, child: body),
    );
  }
}

// MARK: - Edit Body

class _EditBody extends StatelessWidget {
  const _EditBody({required this.draft, required this.onChanged});

  final OverviewEditDraft draft;
  final ValueChanged<OverviewEditDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final intro = Text(
      overviewEditIntro,
      style: context.text.body.copyWith(color: context.colors.subtext),
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
          const SectionLabel(overviewEditShownLabel),
          _EditList(draft: draft, onChanged: onChanged),
          restore,
        ],
      ),
    );
  }
}

// MARK: - Edit List

class _EditList extends StatelessWidget {
  const _EditList({required this.draft, required this.onChanged});

  final OverviewEditDraft draft;
  final ValueChanged<OverviewEditDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final shown = draft.shown;
    final hidden = draft.hidden;
    final headerIndex = shown.length;
    final hintIndex = headerIndex + 1;
    final itemCount = hintIndex + (hidden.isEmpty ? 1 : hidden.length);

    Widget rowFor(OverviewWidgetKind kind, int index) {
      return OverviewEditRow(
        key: ValueKey(kind),
        index: index,
        card: overviewCardFor(kind)!,
      );
    }

    Widget itemAt(BuildContext context, int index) {
      if (index < headerIndex) return rowFor(shown[index], index);
      if (index == headerIndex) {
        return const SectionLabel(
          overviewEditHiddenLabel,
          key: _hiddenHeaderKey,
        );
      }
      if (hidden.isEmpty) {
        return const OverviewEditHiddenHint(
          key: _hiddenHintKey,
          text: overviewEditHiddenHint,
        );
      }
      return rowFor(hidden[index - hintIndex], index);
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: itemAt,
      proxyDecorator: (child, _, _) => _DragProxy(child: child),
      onReorderItem: (from, to) => onChanged(draft.move(from, to)),
    );
  }
}

class _DragProxy extends StatelessWidget {
  const _DragProxy({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.raised,
      elevation: _dragElevation,
      borderRadius: _dragRadius,
      child: child,
    );
  }
}
