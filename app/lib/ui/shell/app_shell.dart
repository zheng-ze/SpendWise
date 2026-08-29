import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/layout_breakpoints.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/status_banner.dart';
import 'package:spendwise/ui/shell/storage_warning.dart';

const _layoutTransitionDuration = Duration(milliseconds: 180);

const _destinationLabels = {
  ShellDestination.transactions: 'Transactions',
  ShellDestination.stats: 'Stats',
  ShellDestination.accounts: 'Accounts',
  ShellDestination.settings: 'Settings',
};

const _destinationIcons = {
  ShellDestination.transactions: Icons.receipt_long_outlined,
  ShellDestination.stats: Icons.pie_chart_outline,
  ShellDestination.accounts: Icons.account_balance_wallet_outlined,
  ShellDestination.settings: Icons.settings_outlined,
};

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.bodies = const {}});

  final Map<ShellDestination, WidgetBuilder> bodies;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _useRail = false;
  bool _extended = false;

  // Two thresholds per mode, so a window sitting right at a boundary does not
  // flip layouts back and forth as it resizes by a pixel.
  void _updateLayoutMode(double width) {
    final useRail = _useRail
        ? width >= LayoutBreakpoints.railExit
        : width >= LayoutBreakpoints.railEnter;
    final extended = _extended
        ? width >= LayoutBreakpoints.extendedRailExit
        : width >= LayoutBreakpoints.extendedRailEnter;

    if (useRail != _useRail || extended != _extended) {
      setState(() {
        _useRail = useRail;
        _extended = extended;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDestinationProvider);
    _updateLayoutMode(MediaQuery.sizeOf(context).width);

    void select(int index) =>
        ref.read(selectedDestinationProvider.notifier).state =
            ShellDestination.values[index];

    final content = Column(
      children: [
        const StorageWarning(),
        Expanded(
          child: Stack(
            children: [
              _DestinationStacks(selected: selected, bodies: widget.bodies),
              const StatusBanner(),
            ],
          ),
        ),
      ],
    );

    final body = !_useRail
        ? Scaffold(
            key: const ValueKey('bottom-nav'),
            body: content,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selected.index,
              onDestinationSelected: select,
              destinations: [
                for (final destination in ShellDestination.values)
                  NavigationDestination(
                    icon: Icon(_destinationIcons[destination]),
                    label: _destinationLabels[destination]!,
                  ),
              ],
            ),
          )
        : Scaffold(
            key: const ValueKey('rail'),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selected.index,
                  onDestinationSelected: select,
                  labelType: _extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  extended: _extended,
                  destinations: [
                    for (final destination in ShellDestination.values)
                      NavigationRailDestination(
                        icon: Icon(_destinationIcons[destination]),
                        label: Text(_destinationLabels[destination]!),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
          );

    return AnimatedSwitcher(duration: _layoutTransitionDuration, child: body);
  }
}

// IndexedStack keeps every destination's Flow mounted, which is what makes a
// drilled-in stack survive a switch away and back — each Flow owns its own
// Navigator (ADR-0059), so the shell does not need one of its own.
class _DestinationStacks extends StatelessWidget {
  const _DestinationStacks({required this.selected, required this.bodies});

  final ShellDestination selected;

  final Map<ShellDestination, WidgetBuilder> bodies;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selected.index,
      children: [
        for (final destination in ShellDestination.values)
          KeyedSubtree(
            key: ValueKey(destination),
            child:
                (bodies[destination] ?? (context) => const SizedBox.shrink())(
                  context,
                ),
          ),
      ],
    );
  }
}
