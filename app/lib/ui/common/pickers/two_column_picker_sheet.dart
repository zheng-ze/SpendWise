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

// MARK: - Constants
const _sheetHeightFactor = 0.7;

const _compactRowHorizontalPadding = 12.0;

const _compactTitleGap = 8.0;

const _compactLeadingWidth = 28.0;

const _compactTrailingWidth = 18.0;

const _listTileMinTrailingReservation = 32.0;

const _compactTrailingReservation =
    _compactTrailingWidth + _compactTitleGap > _listTileMinTrailingReservation
    ? _compactTrailingWidth + _compactTitleGap
    : _listTileMinTrailingReservation;

const _rowChromeWidth =
    2 * _compactRowHorizontalPadding +
    _compactLeadingWidth +
    _compactTitleGap +
    _compactTrailingReservation;

const _stackedChildIndent = 24.0;

const _columnsHeightFraction = 0.5;

const _columnDividerWidth = 1.0;

Future<PickerOutcome?> showTwoColumnPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerOption> groups,
  String? selectedId,
  bool useRootNavigator = false,
  AppSheetPresentation Function(BuildContext)? sheetPresentation,
}) {
  if (sheetPresentation != null) {
    return showPickerAppSheet<PickerOutcome>(
      context,
      presentation: sheetPresentation,
      builder: (_) => AppPickerSheet(
        title: title,
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
  });

  final String title;
  final List<PickerOption> groups;
  final String? selectedId;

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
    this.compact = false,
  });

  final bool compact;
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
      contentPadding: compact
          ? const EdgeInsets.symmetric(horizontal: _compactRowHorizontalPadding)
          : null,
      horizontalTitleGap: compact ? _compactTitleGap : null,
      minLeadingWidth: compact ? _compactLeadingWidth : null,
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
          compact: true,
          option: group,
          selected: group.id == widget.selectedId,
          active: group.id == _expandedId,
          onTap: () => _tapParent(group),
        ),
    ];
    final childRows = [
      for (final child in children)
        _PickerRow(
          compact: true,
          option: child,
          selected: child.id == widget.selectedId,
          active: false,
          onTap: () => Navigator.of(context).pop(PickerChose(child.id)),
        ),
    ];

    final sideBySideMinWidth =
        2 * (_rowChromeWidth + _longestWordWidth(context, widget.groups)) +
        _columnDividerWidth;

    final phone =
        AppSheetAlertSlot.maybeOf(context)?.presentation ==
        AppSheetPresentation.phone;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = phone || constraints.maxWidth < sideBySideMinWidth;
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
      child: SingleChildScrollView(child: Column(children: children)),
    );
    final height = MediaQuery.sizeOf(context).height * _columnsHeightFraction;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(child: Column(children: parents)),
          ),
          Expanded(child: childColumn),
        ],
      ),
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

double _longestWordWidth(BuildContext context, List<PickerOption> groups) {
  final style = Theme.of(context).textTheme.bodyLarge;
  final scaler = MediaQuery.textScalerOf(context);
  final labels = [
    for (final group in groups) ...[
      group.label,
      for (final c in group.children) c.label,
    ],
  ];
  var widest = 0.0;
  for (final word in labels.expand((label) => label.split(' '))) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  return widest;
}
