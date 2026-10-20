import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/sidebar_status_view_model.dart';
import 'package:spendwise/ui/shell/shell_destinations.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/spendwise_wordmark.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Constants
const _sidebarKey = ValueKey('sidebar');

const _sidebarWidth = 172.0;
const _sidebarPadding = EdgeInsets.fromLTRB(8, 12, 8, 12);
const _sidebarDividerWidth = 1.0;
const _wordmarkFontSize = 18.0;
const _wordmarkPadding = EdgeInsets.fromLTRB(8, 0, 8, 16);
const _sidebarItemPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 9);
const _sidebarItemGap = 2.0;
const _sidebarItemCornerRadius = 12.0;
const _sidebarIconSize = 20.0;
const _sidebarLabelGap = 10.0;
const _sidebarLabelFontSize = 13.0;
const _sidebarAddGap = 8.0;
const _sidebarAddVerticalPadding = 12.0;
const _unselectedBackground = Colors.transparent;
const _addEntryLabel = 'Add entry';
const _syncLabelFontSize = 11.0;
const _syncStatusPadding = EdgeInsets.fromLTRB(10, 8, 10, 0);

const _loopDestinations = [
  ShellDestination.overview,
  ShellDestination.history,
  ShellDestination.money,
];

// MARK: - DesktopSidebar
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
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
      key: _sidebarKey,
      width: _sidebarWidth,
      color: colors.surface,
      padding: _sidebarPadding,
      child: _SidebarScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: _wordmarkPadding,
              child: SpendWiseWordmark(fontSize: _wordmarkFontSize),
            ),
            for (final (index, destination) in _loopDestinations.indexed) ...[
              if (index > 0) const SizedBox(height: _sidebarItemGap),
              _SidebarDestination(
                destination: destination,
                selected: selected,
                onSelected: onDestinationSelected,
              ),
            ],
            const SizedBox(height: _sidebarAddGap),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text(_addEntryLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: _sidebarAddVerticalPadding,
                ),
              ),
            ),
            const Spacer(),
            _SidebarDestination(
              destination: ShellDestination.settings,
              selected: selected,
              onSelected: onDestinationSelected,
            ),
            const _SidebarSyncStatus(),
          ],
        ),
      ),
    );
  }
}

// MARK: - SidebarSyncStatus
class _SidebarSyncStatus extends ConsumerWidget {
  const _SidebarSyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final label = ref.watch(sidebarStatusViewModelProvider).syncLabel;
    return Padding(
      padding: _syncStatusPadding,
      child: Text(
        label,
        style: TextStyle(fontSize: _syncLabelFontSize, color: colors.subtext),
      ),
    );
  }
}

// MARK: - SidebarScroll
class _SidebarScroll extends StatelessWidget {
  const _SidebarScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

// MARK: - SidebarDestination
class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
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
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(_sidebarItemCornerRadius),
        onTap: () => onSelected(destination),
        child: Container(
          padding: _sidebarItemPadding,
          decoration: BoxDecoration(
            color: isSelected ? colors.tint : _unselectedBackground,
            borderRadius: BorderRadius.circular(_sidebarItemCornerRadius),
          ),
          child: Row(
            children: [
              Icon(
                destinationIcons[destination],
                size: _sidebarIconSize,
                color: isSelected ? colors.action : colors.subtext,
              ),
              const SizedBox(width: _sidebarLabelGap),
              Expanded(
                child: Text(
                  destinationLabels[destination]!,
                  style: TextStyle(
                    fontSize: _sidebarLabelFontSize,
                    fontWeight: isSelected
                        ? selectedDestinationWeight
                        : unselectedDestinationWeight,
                    color: isSelected ? colors.action : colors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: - SidebarDivider
class SidebarDivider extends StatelessWidget {
  const SidebarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: _sidebarDividerWidth,
      color: context.colors.edge,
    );
  }
}
