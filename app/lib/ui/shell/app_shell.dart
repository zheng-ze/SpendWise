import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/shell/day_ticker.dart';
import 'package:spendwise/ui/shell/layout_breakpoints.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/status_banner.dart';

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
  DayTicker? _ticker;

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _ensureTicker(DateTime Function() clock) {
    if (_ticker?.clock == clock) return;
    _ticker?.dispose();
    _ticker = DayTicker(
      clock: clock,
      onDayChanged: () => ref.invalidate(todayProvider),
    );
  }

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
    _ensureTicker(ref.watch(clockProvider));
    _updateLayoutMode(MediaQuery.sizeOf(context).width);

    void select(int index) =>
        ref.read(selectedDestinationProvider.notifier).state =
            ShellDestination.values[index];

    final content = Stack(
      children: [
        _DestinationStacks(selected: selected, bodies: widget.bodies),
        const StatusBanner(),
      ],
    );

    final body = _useRail
        ? _RailLayout(
            key: const ValueKey('rail'),
            content: content,
            selectedIndex: selected.index,
            onDestinationSelected: select,
            extended: _extended,
          )
        : _BottomBarLayout(
            key: const ValueKey('bottom-nav'),
            content: content,
            selectedIndex: selected.index,
            onDestinationSelected: select,
          );

    return AnimatedSwitcher(duration: _layoutTransitionDuration, child: body);
  }
}

class _BottomBarLayout extends StatelessWidget {
  const _BottomBarLayout({
    super.key,
    required this.content,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final Widget content;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('bottom-nav'),
      body: content,
      bottomNavigationBar: _InsetNavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}

class _InsetNavigationBar extends StatelessWidget {
  const _InsetNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      for (final destination in ShellDestination.values)
        NavigationDestination(
          icon: Icon(_destinationIcons[destination]),
          label: _destinationLabels[destination]!,
        ),
    ];
    final bar = NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: bar,
    );
    final unpadded = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: clipped,
    );
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: unpadded,
    );

    return SafeArea(top: false, child: padded);
  }
}

class _RailLayout extends StatelessWidget {
  const _RailLayout({
    super.key,
    required this.content,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
  });

  final Widget content;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      for (final destination in ShellDestination.values)
        NavigationRailDestination(
          icon: Icon(_destinationIcons[destination]),
          label: Text(_destinationLabels[destination]!),
        ),
    ];
    final rail = NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      extended: extended,
      destinations: destinations,
    );
    final pane = Expanded(child: content);
    final row = Row(children: [rail, const VerticalDivider(width: 1), pane]);

    return Scaffold(key: const ValueKey('rail'), body: row);
  }
}

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
