import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_destinations.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Geometry
const openRailKey = ValueKey('open-rail');

const openRailGutter = 72.0;
const openRailRightInset = 9.0;
const openRailBottomInset = 10.0;
const openRailWidth = 54.0;
const openRailCornerRadius = 18.0;
const openRailBorderWidth = 1.0;

const _railPadding = EdgeInsets.symmetric(vertical: 12, horizontal: 2);
const _railItemGap = 14.0;
const _railAddTopGap = 2.0;
const _railIconSize = 24.0;
const _railLabelFontSize = 8.0;
const _railLabelGap = 4.0;
const _railItemCornerRadius = 10.0;
const _railMinHitSize = 48.0;
const _railAddBadgeSize = 32.0;
const _railAddBadgePadding = 5.0;
const _railAddBadgeRadius = 10.0;
const _railAddIconSize = 32.0;
const _railAddLabel = 'Add';

const _openRailOrder = [
  ShellDestination.overview,
  ShellDestination.history,
  ShellDestination.trends,
  ShellDestination.money,
  ShellDestination.settings,
];

// MARK: - OpenRail
class OpenRail extends StatelessWidget {
  const OpenRail({
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
    return Container(
      key: openRailKey,
      width: openRailWidth,
      padding: _railPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.edge, width: openRailBorderWidth),
        borderRadius: BorderRadius.circular(openRailCornerRadius),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, destination) in _openRailOrder.indexed) ...[
              if (index > 0) const SizedBox(height: _railItemGap),
              _RailDestination(
                destination: destination,
                selected: selected,
                onSelected: onDestinationSelected,
              ),
            ],
            const SizedBox(height: _railAddTopGap + _railItemGap),
            _RailAdd(onTap: onAdd),
          ],
        ),
      ),
    );
  }
}

// MARK: - RailDestination
class _RailDestination extends StatelessWidget {
  const _RailDestination({
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
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(_railItemCornerRadius),
        onTap: () => onSelected(destination),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _railMinHitSize,
            minHeight: _railMinHitSize,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                destinationIcons[destination],
                size: _railIconSize,
                color: foreground,
              ),
              const SizedBox(height: _railLabelGap),
              Text(
                destinationLabels[destination]!,
                style: TextStyle(
                  fontSize: _railLabelFontSize,
                  fontWeight: isSelected
                      ? selectedDestinationWeight
                      : unselectedDestinationWeight,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: - RailAdd
class _RailAdd extends StatelessWidget {
  const _RailAdd({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(_railItemCornerRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _railMinHitSize,
            minHeight: _railMinHitSize,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _railAddBadgeSize + _railAddBadgePadding * 2,
                height: _railAddBadgeSize + _railAddBadgePadding * 2,
                padding: const EdgeInsets.all(_railAddBadgePadding),
                decoration: BoxDecoration(
                  color: colors.action,
                  borderRadius: BorderRadius.circular(_railAddBadgeRadius),
                ),
                child: Icon(
                  Icons.add,
                  size: _railAddIconSize,
                  color: colors.onAction,
                ),
              ),
              const SizedBox(height: _railLabelGap),
              Text(
                _railAddLabel,
                style: TextStyle(
                  fontSize: _railLabelFontSize,
                  fontWeight: selectedDestinationWeight,
                  color: colors.action,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
