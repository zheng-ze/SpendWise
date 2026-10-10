import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/shell/day_ticker.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/shell/layout_breakpoints.dart';
import 'package:spendwise/ui/shell/settings_route.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/status_banner.dart';

const _layoutTransitionDuration = Duration(milliseconds: 180);

const _destinationLabels = {
  ShellDestination.transactions: 'Transactions',
  ShellDestination.stats: 'Stats',
  ShellDestination.accounts: 'Accounts',
};

const _settingsLabel = 'Settings';

const _settingsIcon = Icons.settings_outlined;

final _settingsIndex = ShellDestination.values.length;

const _destinationIcons = {
  ShellDestination.transactions: Icons.receipt_long_outlined,
  ShellDestination.stats: Icons.pie_chart_outline,
  ShellDestination.accounts: Icons.account_balance_wallet_outlined,
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
  Route<void>? _settingsRoute;
  late final ProviderSubscription<bool> _settingsOpenSubscription;

  // A widget-scoped listener is paused while the SettingsRoute covers the
  // shell, and that is exactly when the flag must be able to remove the route.
  @override
  void initState() {
    super.initState();
    _settingsOpenSubscription = ProviderScope.containerOf(
      context,
      listen: false,
    ).listen(settingsOpenProvider, (_, _) => _scheduleReconcile());
  }

  @override
  void dispose() {
    _settingsOpenSubscription.close();
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

  void _closeSettings() =>
      ref.read(settingsOpenProvider.notifier).state = false;

  void _scheduleReconcile() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _reconcileSettingsRoute())
      ..ensureVisualUpdate();
  }

  void _reconcileSettingsRoute() {
    if (!mounted) return;
    final wanted = ref.read(settingsOpenProvider) && !_useRail;
    final route = _settingsRoute;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (wanted && route == null) {
      final created = SettingsRoute(
        backLabel: _destinationLabels[ref.read(selectedDestinationProvider)]!,
        onEnded: _closeSettings,
      );
      _settingsRoute = created;
      navigator.push(created);
    } else if (!wanted && route != null) {
      _settingsRoute = null;
      navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDestinationProvider);
    final settingsOpen = ref.watch(settingsOpenProvider);
    _ensureTicker(ref.watch(clockProvider));
    _updateLayoutMode(MediaQuery.sizeOf(context).width);

    final settingsInContent = settingsOpen && _useRail;
    final wantsRoute = settingsOpen && !_useRail;
    if (wantsRoute != (_settingsRoute != null)) {
      _scheduleReconcile();
    }

    void select(int index) {
      if (index == _settingsIndex) {
        ref.read(settingsOpenProvider.notifier).state = true;
        return;
      }
      _closeSettings();
      ref.read(selectedDestinationProvider.notifier).state =
          ShellDestination.values[index];
    }

    final content = Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: settingsInContent,
          child: _DestinationStacks(selected: selected, bodies: widget.bodies),
        ),
        if (settingsInContent) SettingsFlow(onEnded: _closeSettings),
        const StatusBanner(),
      ],
    );

    final body = _useRail
        ? _RailLayout(
            key: const ValueKey('rail'),
            content: content,
            selectedIndex: settingsInContent ? _settingsIndex : selected.index,
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

  static const _barCornerRadius = 20.0;

  static const _barInsets = EdgeInsets.fromLTRB(8, 0, 8, 8);

  @override
  Widget build(BuildContext context) {
    final destinations = [
      for (final destination in ShellDestination.values)
        NavigationDestination(
          icon: Icon(_destinationIcons[destination]),
          label: _destinationLabels[destination]!,
        ),
      const NavigationDestination(
        icon: Icon(_settingsIcon),
        label: _settingsLabel,
      ),
    ];
    final bar = NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(_barCornerRadius),
      child: bar,
    );
    final unpadded = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: clipped,
    );
    final padded = Padding(padding: _barInsets, child: unpadded);

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

  static const _railDividerWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      for (final destination in ShellDestination.values)
        NavigationRailDestination(
          icon: Icon(_destinationIcons[destination]),
          label: Text(_destinationLabels[destination]!),
        ),
      const NavigationRailDestination(
        icon: Icon(_settingsIcon),
        label: Text(_settingsLabel),
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
    final row = Row(
      children: [
        rail,
        const VerticalDivider(width: _railDividerWidth),
        pane,
      ],
    );

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
