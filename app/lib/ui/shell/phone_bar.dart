import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_destinations.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _barKey = ValueKey('phone-bar');

const _barMargin = EdgeInsets.fromLTRB(8, 0, 8, 8);
const _barPadding = EdgeInsets.fromLTRB(4, 6, 4, 6);
const _barCornerRadius = 20.0;
const _barBorderWidth = 1.0;
const _barIconSize = 24.0;
const _barLabelFontSize = 10.0;
const _barLabelGap = 3.0;
const _barItemCornerRadius = 14.0;
const _barItemVerticalPadding = 4.0;
const _addBadgeSize = 40.0;
const _addBadgeRadius = 20.0;
const _addIconSize = 22.0;
const _addLabel = 'Add';

const _destinationsBeforeAdd = [
  ShellDestination.overview,
  ShellDestination.trends,
];

const _destinationsAfterAdd = [
  ShellDestination.money,
  ShellDestination.settings,
];

// MARK: - PhoneBar
class PhoneBar extends StatelessWidget {
  const PhoneBar({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    required this.onAdd,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onDestinationSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bar = Container(
      key: _barKey,
      margin: _barMargin,
      padding: _barPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.edge, width: _barBorderWidth),
        borderRadius: BorderRadius.circular(_barCornerRadius),
      ),
      child: Row(
        children: [
          for (final destination in _destinationsBeforeAdd)
            _BarDestination(
              destination: destination,
              selected: selected,
              onSelected: onDestinationSelected,
            ),
          _BarAdd(onTap: onAdd),
          for (final destination in _destinationsAfterAdd)
            _BarDestination(
              destination: destination,
              selected: selected,
              onSelected: onDestinationSelected,
            ),
        ],
      ),
    );
    final unpadded = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: bar,
    );

    return SafeArea(top: false, child: unpadded);
  }
}

// MARK: - BarSlot
class _BarSlot extends StatelessWidget {
  const _BarSlot({
    required this.selected,
    required this.onTap,
    required this.children,
  });

  final bool? selected;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(_barItemCornerRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _barItemVerticalPadding,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

// MARK: - BarDestination
class _BarDestination extends StatelessWidget {
  const _BarDestination({
    required this.destination,
    required this.selected,
    required this.onSelected,
  });

  final ShellDestination destination;
  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSelected = destination == selected;
    final foreground = isSelected ? colors.action : colors.subtext;
    return _BarSlot(
      selected: isSelected,
      onTap: () => onSelected(destination),
      children: [
        Icon(
          destinationIcons[destination],
          size: _barIconSize,
          color: foreground,
        ),
        const SizedBox(height: _barLabelGap),
        Text(
          destinationLabels[destination]!,
          style: TextStyle(
            fontSize: _barLabelFontSize,
            fontWeight: isSelected
                ? selectedDestinationWeight
                : unselectedDestinationWeight,
            color: foreground,
          ),
        ),
      ],
    );
  }
}

// MARK: - BarAdd
class _BarAdd extends StatelessWidget {
  const _BarAdd({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _BarSlot(
      selected: null,
      onTap: onTap,
      children: [
        Container(
          width: _addBadgeSize,
          height: _addBadgeSize,
          decoration: BoxDecoration(
            color: colors.action,
            borderRadius: BorderRadius.circular(_addBadgeRadius),
          ),
          child: Icon(Icons.add, size: _addIconSize, color: colors.onAction),
        ),
        const SizedBox(height: _barLabelGap),
        Text(
          _addLabel,
          style: TextStyle(
            fontSize: _barLabelFontSize,
            fontWeight: selectedDestinationWeight,
            color: colors.action,
          ),
        ),
      ],
    );
  }
}
