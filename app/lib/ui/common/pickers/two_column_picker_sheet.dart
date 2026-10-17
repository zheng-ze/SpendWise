import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

// MARK: - PickerOption
@immutable
class PickerOption {
  const PickerOption({
    required this.id,
    required this.label,
    this.leading,
    this.children = const [],
  });

  final String id;
  final String label;
  final Widget? leading;
  final List<PickerOption> children;
}

// MARK: - PickerOutcome
@immutable
sealed class PickerOutcome {
  const PickerOutcome();
}

// MARK: - PickerChose
class PickerChose extends PickerOutcome {
  const PickerChose(this.id);

  final String id;
}

// MARK: - PickerCleared
class PickerCleared extends PickerOutcome {
  const PickerCleared();
}

// MARK: - Constants
const _sheetHeightFactor = 0.7;

const _sideBySideMinWidth = 400.0;

const _stackedChildIndent = 24.0;

const _columnDividerWidth = 1.0;

Future<PickerOutcome?> showTwoColumnPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerOption> groups,
  String? selectedId,
  bool allowsNone = false,
  bool useRootNavigator = false,
  AppSheetPresentation? sheetPresentation,
}) {
  if (sheetPresentation != null) {
    return showAppSheet<PickerOutcome>(
      context,
      presentation: sheetPresentation,
      builder: (_) => AppPickerSheet(
        title: title,
        trailing: allowsNone ? const _NoneButton() : null,
        body: PickerGroupBody(groups: groups, selectedId: selectedId),
      ),
    );
  }
  return showModalBottomSheet<PickerOutcome>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    builder: (_) => FractionallySizedBox(
      heightFactor: _sheetHeightFactor,
      child: TwoColumnPickerSheet(
        title: title,
        groups: groups,
        selectedId: selectedId,
        allowsNone: allowsNone,
      ),
    ),
  );
}

// MARK: - TwoColumnPickerSheet
class TwoColumnPickerSheet extends StatefulWidget {
  const TwoColumnPickerSheet({
    super.key,
    required this.title,
    required this.groups,
    this.selectedId,
    this.allowsNone = false,
  });

  final String title;
  final List<PickerOption> groups;
  final String? selectedId;
  final bool allowsNone;

  @override
  State<TwoColumnPickerSheet> createState() => _TwoColumnPickerSheetState();
}

// MARK: - TwoColumnPickerSheetState
class _TwoColumnPickerSheetState extends State<TwoColumnPickerSheet> {
  String? _expandedId;

  static const _cancelButtonWidth = 88.0;

  void _tapParent(PickerOption parent) {
    if (parent.children.isEmpty || _expandedId == parent.id) {
      Navigator.of(context).pop(PickerChose(parent.id));
      return;
    }
    setState(() => _expandedId = parent.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expanded = widget.groups
        .where((group) => group.id == _expandedId)
        .firstOrNull;

    return Column(
      children: [
        AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.title),
          centerTitle: true,
          leading: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          leadingWidth: _cancelButtonWidth,
          actions: [
            if (widget.allowsNone)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const PickerCleared()),
                child: const Text('None'),
              ),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final group in widget.groups)
                      _PickerRow(
                        option: group,
                        selected: group.id == widget.selectedId,
                        active: group.id == _expandedId,
                        onTap: () => _tapParent(group),
                      ),
                  ],
                ),
              ),
              VerticalDivider(
                width: _columnDividerWidth,
                color: theme.dividerColor,
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final child
                        in expanded?.children ?? const <PickerOption>[])
                      _PickerRow(
                        option: child,
                        selected: child.id == widget.selectedId,
                        active: false,
                        onTap: () =>
                            Navigator.of(context).pop(PickerChose(child.id)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// MARK: - PickerRow
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.option,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final PickerOption option;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  static const _selectedFillOpacity = 0.15;

  static const _drillInIconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primary.withValues(alpha: _selectedFillOpacity)
        : active
        ? theme.colorScheme.surfaceContainerHighest
        : null;

    return ListTile(
      tileColor: background,
      selected: selected,
      onTap: onTap,
      leading: option.leading,
      title: Text(
        option.label,
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      trailing: option.children.isEmpty
          ? null
          : const Icon(Icons.chevron_right, size: _drillInIconSize),
    );
  }
}

// MARK: - NoneButton
class _NoneButton extends StatelessWidget {
  const _NoneButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: pickerNoneKey,
      onPressed: () => Navigator.of(context).pop(const PickerCleared()),
      child: const Text('None'),
    );
  }
}

// MARK: - PickerGroupBody
class PickerGroupBody extends StatefulWidget {
  const PickerGroupBody({super.key, required this.groups, this.selectedId});

  final List<PickerOption> groups;
  final String? selectedId;

  @override
  State<PickerGroupBody> createState() => _PickerGroupBodyState();
}

class _PickerGroupBodyState extends State<PickerGroupBody> {
  String? _expandedId;

  void _tapParent(PickerOption parent) {
    if (parent.children.isEmpty || _expandedId == parent.id) {
      Navigator.of(context).pop(PickerChose(parent.id));
      return;
    }
    setState(() => _expandedId = parent.id);
  }

  @override
  Widget build(BuildContext context) {
    final expandedIndex = widget.groups.indexWhere(
      (group) => group.id == _expandedId,
    );
    final children = expandedIndex < 0
        ? const <PickerOption>[]
        : widget.groups[expandedIndex].children;
    final parentRows = [
      for (final group in widget.groups)
        _PickerRow(
          option: group,
          selected: group.id == widget.selectedId,
          active: group.id == _expandedId,
          onTap: () => _tapParent(group),
        ),
    ];
    final childRows = [
      for (final child in children)
        _PickerRow(
          option: child,
          selected: child.id == widget.selectedId,
          active: false,
          onTap: () => Navigator.of(context).pop(PickerChose(child.id)),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _sideBySideMinWidth;
        if (!narrow) {
          return _SideBySideGroups(parents: parentRows, children: childRows);
        }
        return _StackedGroups(
          parents: parentRows,
          expandedIndex: expandedIndex,
          children: childRows,
        );
      },
    );
  }
}

// MARK: - SideBySideGroups
class _SideBySideGroups extends StatelessWidget {
  const _SideBySideGroups({required this.parents, required this.children});

  final List<Widget> parents;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      width: _columnDividerWidth,
      color: Theme.of(context).dividerColor,
    );
    final childColumn = DecoratedBox(
      decoration: BoxDecoration(border: Border(left: divider)),
      child: Column(children: children),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: parents)),
        Expanded(child: childColumn),
      ],
    );
  }
}

// MARK: - StackedGroups
class _StackedGroups extends StatelessWidget {
  const _StackedGroups({
    required this.parents,
    required this.children,
    required this.expandedIndex,
  });

  final List<Widget> parents;
  final List<Widget> children;
  final int expandedIndex;

  @override
  Widget build(BuildContext context) {
    final indented = [
      for (final child in children)
        Padding(
          padding: const EdgeInsets.only(left: _stackedChildIndent),
          child: child,
        ),
    ];
    final rows = [...parents];
    if (expandedIndex >= 0) rows.insertAll(expandedIndex + 1, indented);

    return Column(children: rows);
  }
}
