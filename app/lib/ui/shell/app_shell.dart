import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/shell/day_ticker.dart';
import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/phone_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/status_banner.dart';

// MARK: - Constants
const phoneDestinations = [
  ShellDestination.overview,
  ShellDestination.trends,
  ShellDestination.money,
  ShellDestination.settings,
];

const desktopDestinations = [
  ShellDestination.overview,
  ShellDestination.history,
  ShellDestination.trends,
  ShellDestination.money,
  ShellDestination.settings,
];

const _fallbackStackIndex = 0;

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
    final desktop =
        ref.watch(shellLayoutModeProvider) == ShellLayoutMode.desktop;
    _ensureTicker(ref.watch(clockProvider));

    final content = Stack(
      fit: StackFit.expand,
      children: [
        _DestinationStacks(
          selected: selected,
          order: desktop ? desktopDestinations : phoneDestinations,
          bodies: widget.bodies,
        ),
        const StatusBanner(),
      ],
    );

    if (desktop) {
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
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      key: const ValueKey('phone-layout'),
      body: content,
      bottomNavigationBar: PhoneBar(
        selected: selected,
        onDestinationSelected: _select,
        onAdd: () => _openNewEntry(context),
      ),
    );
  }
}

// MARK: - DestinationStacks
class _DestinationStacks extends StatelessWidget {
  const _DestinationStacks({
    required this.selected,
    required this.order,
    required this.bodies,
  });

  final ShellDestination selected;

  final List<ShellDestination> order;

  final Map<ShellDestination, WidgetBuilder> bodies;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = order.indexOf(selected);
    return IndexedStack(
      index: selectedIndex < 0 ? _fallbackStackIndex : selectedIndex,
      children: [
        for (final destination in order)
          KeyedSubtree(
            key: ValueKey(destination),
            child: DestinationActivity(
              active: destination == selected,
              child:
                  (bodies[destination] ?? (context) => const SizedBox.shrink())(
                    context,
                  ),
            ),
          ),
      ],
    );
  }
}
