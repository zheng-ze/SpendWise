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
import 'package:spendwise/ui/shell/shell_providers.dart';
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
const _minimumSafeBodyWidth = 0.0;

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

  @override
  void dispose() {
    _addController?.ownerDisposed(context);
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
    if (ref.read(newEntryPresentationProvider) ==
        NewEntryPresentation.presented) {
      _addController?.dismiss();
    }
  }

  void _dismissNewEntry() => _addController?.dismiss();

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
    final addPresented =
        ref.watch(newEntryPresentationProvider) ==
        NewEntryPresentation.presented;
    _ensureTicker(ref.watch(clockProvider));

    if (mode == ShellLayoutMode.desktop) {
      final navigation = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesktopSidebar(
            selected: selected,
            onDestinationSelected: _select,
            onAdd: () => _openNewEntry(context),
          ),
          const SidebarDivider(),
        ],
      );
      final navigationRegion = SizedBox(
        width: desktopSidebarNavigationWidth,
        child: GestureDetector(
          behavior: addPresented
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
          onTap: addPresented ? _dismissNewEntry : null,
          child: navigation,
        ),
      );
      return Scaffold(
        key: const ValueKey('sidebar-layout'),
        body: Row(
          children: [
            navigationRegion,
            Expanded(
              child: _ShellStack(
                selected: selected,
                bodies: widget.bodies,
                rail: null,
                mode: mode,
                addPresented: addPresented,
                onNavigationLaneTap: _dismissNewEntry,
              ),
            ),
          ],
        ),
      );
    }
    final open = mode == ShellLayoutMode.open;
    return Scaffold(
      key: const ValueKey('mobile-layout'),
      body: _ShellStack(
        selected: selected,
        bodies: widget.bodies,
        mode: mode,
        addPresented: addPresented,
        onNavigationLaneTap: _dismissNewEntry,
        rail: open
            ? OpenRail(
                selected: selected,
                onDestinationSelected: _select,
                onAdd: () => _openNewEntry(context),
              )
            : null,
      ),
      bottomNavigationBar: open
          ? null
          : GestureDetector(
              behavior: addPresented
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.deferToChild,
              onTap: addPresented ? _dismissNewEntry : null,
              child: PhoneBar(
                selected: selected,
                onDestinationSelected: _select,
                onAdd: () => _openNewEntry(context),
              ),
            ),
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
    required this.onNavigationLaneTap,
  });

  final ShellDestination selected;
  final Map<ShellDestination, WidgetBuilder> bodies;
  final Widget? rail;
  final ShellLayoutMode mode;
  final bool addPresented;
  final VoidCallback onNavigationLaneTap;

  @override
  Widget build(BuildContext context) {
    final stacks = _DestinationStacks(selected: selected, bodies: bodies);
    final padding = MediaQuery.paddingOf(context);
    final gutter = rail == null
        ? _noRailGutter
        : openRailGutter + padding.right;
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
    final navigationRail = rail;
    final docked = navigationRail == null
        ? null
        : _OpenNavigationLane(
            gutter: gutter,
            rail: navigationRail,
            addPresented: addPresented,
            onBlankTap: onNavigationLaneTap,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final safeBodyWidth = (constraints.maxWidth - padding.horizontal).clamp(
          _minimumSafeBodyWidth,
          double.infinity,
        );
        return ShellPaneScope(
          mode: mode,
          safeBodyWidth: safeBodyWidth,
          addPresented: addPresented,
          child: Stack(
            fit: StackFit.expand,
            children: [
              viewport,
              StatusBanner(rightGutter: gutter),
              ?docked,
            ],
          ),
        );
      },
    );
  }
}

class _OpenNavigationLane extends StatelessWidget {
  const _OpenNavigationLane({
    required this.gutter,
    required this.rail,
    required this.addPresented,
    required this.onBlankTap,
  });

  final double gutter;
  final Widget rail;
  final bool addPresented;
  final VoidCallback onBlankTap;

  @override
  Widget build(BuildContext context) {
    final constrainedRail = LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: constraints.maxHeight),
        child: rail,
      ),
    );
    final safeRail = SafeArea(
      left: false,
      right: false,
      child: constrainedRail,
    );
    final insetRail = Padding(
      padding: const EdgeInsets.only(
        right: openRailRightInset,
        bottom: openRailBottomInset,
      ),
      child: safeRail,
    );
    final alignedRail = Align(
      alignment: Alignment.bottomRight,
      child: insetRail,
    );
    final laneGesture = GestureDetector(
      behavior: addPresented
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      onTap: addPresented ? onBlankTap : null,
      child: alignedRail,
    );
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: gutter,
      child: laneGesture,
    );
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
    return IndexedStack(
      index: selectedIndex < 0 ? _fallbackStackIndex : selectedIndex,
      children: [
        for (final destination in shellDestinations)
          KeyedSubtree(
            key: ValueKey(destination),
            child: DestinationActivity(
              active: destination == selected,
              child: (bodies[destination] ?? _emptyBody)(context),
            ),
          ),
      ],
    );
  }
}
