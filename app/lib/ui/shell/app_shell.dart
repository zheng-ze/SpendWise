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
  ShellDestination.trends,
  ShellDestination.money,
  ShellDestination.settings,
];

const _fallbackStackIndex = 0;
const _noSafeLeftInset = 0.0;
const _noRailGutter = 0.0;
const _minimumSafeBodyWidth = 0.0;

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
  bool _historyMaterialized = false;

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

  void _select(ShellDestination destination) {
    ref.read(selectedDestinationProvider.notifier).state = destination;
  }

  void _openNewEntry(BuildContext context) {
    final selected = ref.read(selectedDestinationProvider);
    final sourceId = selected == ShellDestination.money
        ? widget.moneySourceId?.call()
        : null;
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
    _historyMaterialized |=
        mode == ShellLayoutMode.open || selected == ShellDestination.history;

    if (mode == ShellLayoutMode.desktop) {
      return Scaffold(
        key: const ValueKey('sidebar-layout'),
        body: Row(
          children: [
            DesktopSidebar(
              selected: selected,
              onDestinationSelected: _select,
              onAdd: () => _openNewEntry(context),
            ),
            const SidebarDivider(),
            Expanded(
              child: _ShellStack(
                selected: selected,
                bodies: widget.bodies,
                historyEnabled: true,
                rail: null,
                mode: mode,
                addPresented: addPresented,
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
        historyEnabled: _historyMaterialized,
        mode: mode,
        addPresented: addPresented,
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
          : PhoneBar(
              selected: selected,
              onDestinationSelected: _select,
              onAdd: () => _openNewEntry(context),
            ),
    );
  }
}

// MARK: - ShellStack
class _ShellStack extends StatelessWidget {
  const _ShellStack({
    required this.selected,
    required this.bodies,
    required this.historyEnabled,
    required this.rail,
    required this.mode,
    required this.addPresented,
  });

  final ShellDestination selected;
  final Map<ShellDestination, WidgetBuilder> bodies;
  final bool historyEnabled;
  final Widget? rail;
  final ShellLayoutMode mode;
  final bool addPresented;

  @override
  Widget build(BuildContext context) {
    final stacks = _DestinationStacks(
      selected: selected,
      bodies: bodies,
      historyEnabled: historyEnabled,
    );
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
    final docked = rail == null
        ? null
        : Positioned(
            right: openRailRightInset,
            bottom: openRailBottomInset,
            child: SafeArea(
              top: false,
              left: false,
              child: LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                  child: rail,
                ),
              ),
            ),
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

// MARK: - DestinationStacks
class _DestinationStacks extends StatelessWidget {
  const _DestinationStacks({
    required this.selected,
    required this.bodies,
    required this.historyEnabled,
  });

  final ShellDestination selected;

  final Map<ShellDestination, WidgetBuilder> bodies;

  final bool historyEnabled;

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
              child: destination == ShellDestination.history && !historyEnabled
                  ? const SizedBox.shrink()
                  : (bodies[destination] ??
                        (context) => const SizedBox.shrink())(context),
            ),
          ),
      ],
    );
  }
}
