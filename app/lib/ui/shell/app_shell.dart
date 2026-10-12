import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/shell/day_ticker.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/status_banner.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

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

const _destinationLabels = {
  ShellDestination.overview: 'Overview',
  ShellDestination.history: 'History',
  ShellDestination.trends: 'Trends',
  ShellDestination.money: 'Money',
  ShellDestination.settings: 'Settings',
};

const _destinationIcons = {
  ShellDestination.overview: Icons.home_outlined,
  ShellDestination.history: Icons.history_outlined,
  ShellDestination.trends: Icons.pie_chart_outline,
  ShellDestination.money: Icons.account_balance_wallet_outlined,
  ShellDestination.settings: Icons.settings_outlined,
};

const _addLabel = 'Add';
const _addEntryLabel = 'Add entry';
const _wordmarkStart = 'Spend';
const _wordmarkEnd = 'Wise';

const _barKey = ValueKey('phone-bar');
const _sidebarKey = ValueKey('sidebar');

const _barMargin = EdgeInsets.fromLTRB(8, 0, 8, 8);
const _barPadding = EdgeInsets.fromLTRB(4, 6, 4, 6);
const _barCornerRadius = 20.0;
const _barBorderWidth = 1.0;
const _barIconSize = 24.0;
const _barLabelFontSize = 10.0;
const _barLabelGap = 3.0;
const _barItemCornerRadius = 14.0;
const _barItemVerticalPadding = 4.0;
const _addBadgeSize = 40.0;
const _addBadgeRadius = 20.0;
const _addIconSize = 22.0;
const _semibold = FontWeight.w600;
const _medium = FontWeight.w500;

const _sidebarWidth = 172.0;
const _sidebarPadding = EdgeInsets.fromLTRB(8, 12, 8, 12);
const _sidebarDividerWidth = 1.0;
const _wordmarkFontSize = 18.0;
const _wordmarkLetterSpacing = -0.8;
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

const _fallbackStackIndex = 0;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.bodies = const {}});

  final Map<ShellDestination, WidgetBuilder> bodies;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

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
      final edge = context.colors.edge;
      return Scaffold(
        key: const ValueKey('sidebar-layout'),
        body: Row(
          children: [
            _Sidebar(selected: selected, onDestinationSelected: _select),
            VerticalDivider(width: _sidebarDividerWidth, color: edge),
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      key: const ValueKey('phone-layout'),
      body: content,
      bottomNavigationBar: _PhoneBar(
        selected: selected,
        onDestinationSelected: _select,
      ),
    );
  }
}

class _PhoneBar extends ConsumerWidget {
  const _PhoneBar({
    required this.selected,
    required this.onDestinationSelected,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bar = Container(
      key: _barKey,
      margin: _barMargin,
      padding: _barPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.edge, width: _barBorderWidth),
        borderRadius: BorderRadius.circular(_barCornerRadius),
      ),
      child: Row(
        children: [
          _BarDestination(
            destination: ShellDestination.overview,
            selected: selected,
            onSelected: onDestinationSelected,
          ),
          _BarDestination(
            destination: ShellDestination.trends,
            selected: selected,
            onSelected: onDestinationSelected,
          ),
          _BarAdd(
            onTap: () => openNewEntry(context: context, ref: ref),
          ),
          _BarDestination(
            destination: ShellDestination.money,
            selected: selected,
            onSelected: onDestinationSelected,
          ),
          _BarDestination(
            destination: ShellDestination.settings,
            selected: selected,
            onSelected: onDestinationSelected,
          ),
        ],
      ),
    );
    final unpadded = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: bar,
    );

    return SafeArea(top: false, child: unpadded);
  }
}

class _BarSlot extends StatelessWidget {
  const _BarSlot({
    required this.selected,
    required this.onTap,
    required this.children,
  });

  final bool? selected;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(_barItemCornerRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _barItemVerticalPadding,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _BarDestination extends StatelessWidget {
  const _BarDestination({
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
    return _BarSlot(
      selected: isSelected,
      onTap: () => onSelected(destination),
      children: [
        Icon(
          _destinationIcons[destination],
          size: _barIconSize,
          color: foreground,
        ),
        const SizedBox(height: _barLabelGap),
        Text(
          _destinationLabels[destination]!,
          style: TextStyle(
            fontSize: _barLabelFontSize,
            fontWeight: isSelected ? _semibold : _medium,
            color: foreground,
          ),
        ),
      ],
    );
  }
}

class _BarAdd extends StatelessWidget {
  const _BarAdd({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _BarSlot(
      selected: null,
      onTap: onTap,
      children: [
        Container(
          width: _addBadgeSize,
          height: _addBadgeSize,
          decoration: BoxDecoration(
            color: colors.action,
            borderRadius: BorderRadius.circular(_addBadgeRadius),
          ),
          child: Icon(Icons.add, size: _addIconSize, color: colors.onAction),
        ),
        const SizedBox(height: _barLabelGap),
        Text(
          _addLabel,
          style: TextStyle(
            fontSize: _barLabelFontSize,
            fontWeight: _semibold,
            color: colors.action,
          ),
        ),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selected, required this.onDestinationSelected});

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Container(
      key: _sidebarKey,
      width: _sidebarWidth,
      color: colors.surface,
      padding: _sidebarPadding,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: _wordmarkPadding,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _wordmarkStart,
                            style: TextStyle(
                              fontSize: _wordmarkFontSize,
                              fontWeight: _semibold,
                              letterSpacing: _wordmarkLetterSpacing,
                              color: colors.text,
                            ),
                          ),
                          TextSpan(
                            text: _wordmarkEnd,
                            style: TextStyle(
                              fontSize: _wordmarkFontSize,
                              fontWeight: _semibold,
                              letterSpacing: _wordmarkLetterSpacing,
                              color: colors.action,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _SidebarDestination(
                    destination: ShellDestination.overview,
                    selected: selected,
                    onSelected: onDestinationSelected,
                  ),
                  const SizedBox(height: _sidebarItemGap),
                  _SidebarDestination(
                    destination: ShellDestination.history,
                    selected: selected,
                    onSelected: onDestinationSelected,
                  ),
                  const SizedBox(height: _sidebarItemGap),
                  _SidebarDestination(
                    destination: ShellDestination.trends,
                    selected: selected,
                    onSelected: onDestinationSelected,
                  ),
                  const SizedBox(height: _sidebarItemGap),
                  _SidebarDestination(
                    destination: ShellDestination.money,
                    selected: selected,
                    onSelected: onDestinationSelected,
                  ),
                  const SizedBox(height: _sidebarAddGap),
                  FilledButton.icon(
                    onPressed: () => openNewEntry(context: context, ref: ref),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
                _destinationIcons[destination],
                size: _sidebarIconSize,
                color: isSelected ? colors.action : colors.subtext,
              ),
              const SizedBox(width: _sidebarLabelGap),
              Text(
                _destinationLabels[destination]!,
                style: TextStyle(
                  fontSize: _sidebarLabelFontSize,
                  fontWeight: isSelected ? _semibold : _medium,
                  color: isSelected ? colors.action : colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
