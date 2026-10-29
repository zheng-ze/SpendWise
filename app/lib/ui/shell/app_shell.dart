import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/shell/day_ticker.dart';
import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/phone_bar.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_pane_geometry.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_presentation_controller.dart';
import 'package:spendwise/ui/shell/status_banner.dart';

// MARK: - Constants
const shellDestinations = [
  ShellDestination.overview,
  ShellDestination.history,
  ShellDestination.money,
  ShellDestination.settings,
];

const _fallbackStackIndex = 0;
const _noSafeLeftInset = 0.0;
const _noRailGutter = 0.0;

Widget _emptyBody(BuildContext context) => const SizedBox.shrink();

// MARK: - AppShell
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.bodies = const {}, this.moneySourceId});

  final Map<ShellDestination, WidgetBuilder> bodies;
  final String? Function()? moneySourceId;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

// MARK: - AppShellState
class _AppShellState extends ConsumerState<AppShell> {
  DayTicker? _ticker;
  NewEntryPresentationController? _addController;
  ShellPresentationController? _presentation;
  Route<dynamic>? _shellRoute;

  @override
  void dispose() {
    _addController?.ownerDisposed(context);
    _presentation?.clearShellConfiguration(_shellRoute);
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

  void _select(ShellDestination destination) {
    ref.read(selectedDestinationProvider.notifier).state = destination;
  }

  void _openNewEntry(BuildContext context) {
    final selected = ref.read(selectedDestinationProvider);
    final sourceId = selected == ShellDestination.money
        ? widget.moneySourceId?.call()
        : null;
    _addController = ref.read(newEntryPresentationControllerProvider);
    openNewEntry(context: context, ref: ref, sourceId: sourceId);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDestinationProvider);
    final mode = ref.watch(shellLayoutModeProvider);
    final presentation = ShellPresentationScope.maybeOf(context);
    final geometry = resolveShellPaneGeometry(
      mode: mode,
      windowSize: MediaQuery.sizeOf(context),
      padding: MediaQuery.paddingOf(context),
    );
    final shellRoute = ModalRoute.of(context);
    _presentation = presentation;
    _shellRoute = shellRoute;
    presentation?.configure(route: shellRoute);
    final sheetCovered = presentation?.isCovered(shellRoute) ?? false;
    final addPresented = presentation?.hasSheets ?? false;
    final suppressNavigation = presentation?.suppressesShellNavigation ?? false;
    _ensureTicker(ref.watch(clockProvider));

    final open = mode == ShellLayoutMode.open;
    final rail = !open
        ? null
        : suppressNavigation
        ? const SizedBox(width: openRailWidth)
        : OpenRail(
            selected: selected,
            onDestinationSelected: _select,
            onAdd: () => _openNewEntry(context),
          );
    final stack = _ShellStack(
      selected: selected,
      bodies: widget.bodies,
      mode: mode,
      addPresented: addPresented,
      geometry: geometry,
      sheetCovered: sheetCovered,
      rail: rail,
    );
    if (mode == ShellLayoutMode.desktop) {
      final sidebar = DesktopSidebar(
        selected: selected,
        onDestinationSelected: _select,
        onAdd: () => _openNewEntry(context),
      );
      final row = Row(
        children: [
          sidebar,
          const SidebarDivider(),
          Expanded(child: stack),
        ],
      );
      final body = SafeArea(top: false, bottom: false, child: row);
      return Scaffold(key: const ValueKey('sidebar-layout'), body: body);
    }
    final phoneBar = open || suppressNavigation
        ? null
        : PhoneBar(
            selected: selected,
            onDestinationSelected: _select,
            onAdd: () => _openNewEntry(context),
          );
    return Scaffold(
      key: const ValueKey('mobile-layout'),
      body: stack,
      bottomNavigationBar: phoneBar,
    );
  }
}

// MARK: - ShellStack
class _ShellStack extends StatelessWidget {
  const _ShellStack({
    required this.selected,
    required this.bodies,
    required this.rail,
    required this.mode,
    required this.addPresented,
    required this.geometry,
    required this.sheetCovered,
  });

  final ShellDestination selected;
  final Map<ShellDestination, WidgetBuilder> bodies;
  final Widget? rail;
  final ShellLayoutMode mode;
  final bool addPresented;
  final ShellPaneGeometry geometry;
  final bool sheetCovered;

  @override
  Widget build(BuildContext context) {
    final rail = this.rail;
    final stacks = _DestinationStacks(selected: selected, bodies: bodies);
    final padding = MediaQuery.paddingOf(context);
    final gutter = rail == null ? _noRailGutter : openRailGutter;
    final viewportChild = MediaQuery.removePadding(
      context: context,
      removeLeft: rail != null,
      removeRight: rail != null,
      child: stacks,
    );
    final viewport = Padding(
      padding: EdgeInsets.only(
        left: rail == null ? _noSafeLeftInset : padding.left,
        right: gutter,
      ),
      child: viewportChild,
    );
    final docked = rail == null
        ? null
        : Positioned(
            right: openRailRightInset,
            bottom: openRailBottomInset,
            child: _ShellRailViewport(rail: rail),
          );
    final content = Stack(
      fit: StackFit.expand,
      children: [
        viewport,
        StatusBanner(rightGutter: gutter),
        ?docked,
      ],
    );
    return ShellPaneScope(
      mode: mode,
      splitOffset: geometry.splitOffset,
      sheetCovered: sheetCovered,
      addPresented: addPresented,
      child: content,
    );
  }
}

class _ShellRailViewport extends StatelessWidget {
  const _ShellRailViewport({required this.rail});

  final Widget rail;

  @override
  Widget build(BuildContext context) {
    final bounded = LayoutBuilder(
      builder: (context, constraints) {
        final bounds = BoxConstraints(maxHeight: constraints.maxHeight);
        return ConstrainedBox(constraints: bounds, child: rail);
      },
    );
    return SafeArea(left: false, right: false, child: bounded);
  }
}

// MARK: - DestinationStacks
class _DestinationStacks extends StatelessWidget {
  const _DestinationStacks({required this.selected, required this.bodies});

  final ShellDestination selected;

  final Map<ShellDestination, WidgetBuilder> bodies;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = shellDestinations.indexOf(selected);
    final children = <Widget>[];
    for (final destination in shellDestinations) {
      final body = (bodies[destination] ?? _emptyBody)(context);
      final activity = DestinationActivity(
        active: destination == selected,
        child: body,
      );
      children.add(KeyedSubtree(key: ValueKey(destination), child: activity));
    }
    return IndexedStack(
      index: selectedIndex < 0 ? _fallbackStackIndex : selectedIndex,
      children: children,
    );
  }
}
