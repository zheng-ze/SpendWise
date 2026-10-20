import 'package:flutter/material.dart';

import 'package:spendwise/ui/shell/shell_destinations.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Geometry
const openRailKey = ValueKey('open-rail');

const openRailNavigationLabel = 'Main navigation';

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
const _railAddIconSize = 22.0;
const _railAddLabel = 'Add';

const _openRailOrder = [
  ShellDestination.overview,
  ShellDestination.history,
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
    return Semantics(
      container: true,
      label: openRailNavigationLabel,
      child: Container(
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
                _RailItem(
                  label: destinationLabels[destination]!,
                  icon: destinationIcons[destination],
                  selected: destination == selected,
                  onTap: () => onDestinationSelected(destination),
                ),
              ],
              const SizedBox(height: _railAddTopGap + _railItemGap),
              _RailItem(
                label: _railAddLabel,
                icon: Icons.add,
                filled: true,
                onTap: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: - RailItem
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool? selected;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSelected = selected ?? false;
    final highlighted = filled || isSelected;
    final foreground = highlighted ? colors.action : colors.subtext;
    final graphic = filled
        ? Container(
            width: _railAddBadgeSize,
            height: _railAddBadgeSize,
            padding: const EdgeInsets.all(_railAddBadgePadding),
            decoration: BoxDecoration(
              color: colors.action,
              borderRadius: BorderRadius.circular(_railAddBadgeRadius),
            ),
            child: Icon(icon, size: _railAddIconSize, color: colors.onAction),
          )
        : Icon(icon, size: _railIconSize, color: foreground);
    return Semantics(
      button: true,
      selected: selected,
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
              graphic,
              const SizedBox(height: _railLabelGap),
              Text(
                label,
                style: TextStyle(
                  fontSize: _railLabelFontSize,
                  fontWeight: highlighted
                      ? selectedDestinationWeight
                      : unselectedDestinationWeight,
                  color: filled ? colors.action : foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
