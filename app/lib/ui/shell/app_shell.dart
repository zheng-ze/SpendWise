import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/status_banner.dart';
import 'package:spendwise/ui/shell/storage_warning.dart';

const _railFromWidth = 720.0;

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

class AppShell extends ConsumerWidget {
  const AppShell({super.key, this.bodies = const {}});

  final Map<ShellDestination, WidgetBuilder> bodies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDestinationProvider);
    final useRail = MediaQuery.sizeOf(context).width >= _railFromWidth;

    void select(int index) =>
        ref.read(selectedDestinationProvider.notifier).state =
            ShellDestination.values[index];

    final content = Column(
      children: [
        const StorageWarning(),
        Expanded(
          child: Stack(
            children: [
              _DestinationStacks(selected: selected, bodies: bodies),
              const StatusBanner(),
            ],
          ),
        ),
      ],
    );

    if (!useRail) {
      return Scaffold(
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
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected.index,
            onDestinationSelected: select,
            labelType: NavigationRailLabelType.all,
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
  }
}

/// [IndexedStack] keeps every destination's [Navigator] mounted, which is what
/// makes a drilled-in stack survive a switch away and back.
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
          _DestinationNavigator(
            destination: destination,
            body: bodies[destination],
          ),
      ],
    );
  }
}

class _DestinationNavigator extends StatelessWidget {
  const _DestinationNavigator({required this.destination, this.body});

  final ShellDestination destination;

  final WidgetBuilder? body;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: ValueKey(destination),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: body ?? (context) => _Placeholder(destination: destination),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.destination});

  final ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_destinationLabels[destination]!)),
      body: const SizedBox.shrink(),
    );
  }
}
