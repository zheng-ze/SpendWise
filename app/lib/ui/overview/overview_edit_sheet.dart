import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
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

const _shownHeadingKey = ValueKey('overview-edit-shown-heading');

const _shownHintKey = ValueKey('overview-edit-shown-hint');

const _spacerKey = ValueKey('overview-edit-section-spacer');

const _hiddenHeadingKey = ValueKey('overview-edit-hidden-heading');

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
          _EditList(draft: draft, onChanged: onChanged),
          const SizedBox(height: _sectionGap),
          restore,
        ],
      ),
    );
  }
}

// MARK: - Edit Layout

class _EditLayout {
  _EditLayout(this.draft) : shown = draft.shown, hidden = draft.hidden;

  final OverviewEditDraft draft;
  final List<OverviewWidgetKind> shown;
  final List<OverviewWidgetKind> hidden;

  int get shownSlots => max(shown.length, 1);
  int get spacerIndex => 1 + shownSlots;
  int get hiddenHeadingIndex => spacerIndex + 1;
  int get hiddenStart => hiddenHeadingIndex + 1;
  int get itemCount => hiddenStart + max(hidden.length, 1);

  bool isShownRow(int index) => index >= 1 && index <= shown.length;

  bool isHiddenRow(int index) =>
      index >= hiddenStart && index < hiddenStart + hidden.length;

  OverviewEditDraft move(int from, int to) {
    final draftFrom = _draftFrom(from);
    if (draftFrom == null) return draft;
    return draft.move(draftFrom, _draftTo(from, to));
  }

  int? _draftFrom(int from) {
    if (isShownRow(from)) return from - 1;
    if (isHiddenRow(from)) return shown.length + 1 + from - hiddenStart;
    return null;
  }

  int _draftTo(int from, int to) {
    final headingAfterRemoval =
        hiddenHeadingIndex - (from < hiddenHeadingIndex ? 1 : 0);
    if (to > headingAfterRemoval) return shown.length + 1;
    final shownAfterRemoval = shown.length - (isShownRow(from) ? 1 : 0);
    return (to - 1).clamp(0, shownAfterRemoval);
  }
}

// MARK: - Edit List

class _EditList extends StatelessWidget {
  const _EditList({required this.draft, required this.onChanged});

  final OverviewEditDraft draft;
  final ValueChanged<OverviewEditDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final layout = _EditLayout(draft);

    Widget slotted(Key key, OverviewEditSlot slot, Widget child) {
      return OverviewEditSectionItem(key: key, slot: slot, child: child);
    }

    Widget rowItem(OverviewWidgetKind kind, int index, bool isLast) {
      final slot = isLast ? OverviewEditSlot.last : OverviewEditSlot.middle;
      final row = OverviewEditRow(index: index, card: overviewCardFor(kind)!);
      return slotted(ValueKey(kind), slot, row);
    }

    Widget itemAt(BuildContext context, int index) {
      if (index == 0) {
        const heading = OverviewEditHeading(text: overviewEditShownLabel);
        return slotted(_shownHeadingKey, OverviewEditSlot.first, heading);
      }
      if (index < layout.spacerIndex) {
        if (layout.shown.isEmpty) {
          const hint = OverviewEditHiddenHint(text: overviewEditShownHint);
          return slotted(_shownHintKey, OverviewEditSlot.last, hint);
        }
        final isLast = index == layout.shownSlots;
        return rowItem(layout.shown[index - 1], index, isLast);
      }
      if (index == layout.spacerIndex) {
        return const SizedBox(key: _spacerKey, height: _sectionGap);
      }
      if (index == layout.hiddenHeadingIndex) {
        const heading = OverviewEditHeading(text: overviewEditHiddenLabel);
        return slotted(_hiddenHeadingKey, OverviewEditSlot.first, heading);
      }
      if (layout.hidden.isEmpty) {
        const hint = OverviewEditHiddenHint(text: overviewEditHiddenHint);
        return slotted(_hiddenHintKey, OverviewEditSlot.last, hint);
      }
      final isLast = index == layout.itemCount - 1;
      return rowItem(layout.hidden[index - layout.hiddenStart], index, isLast);
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: layout.itemCount,
      itemBuilder: itemAt,
      proxyDecorator: (child, _, _) => _DragProxy(child: child),
      onReorderItem: (from, to) => onChanged(layout.move(from, to)),
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
