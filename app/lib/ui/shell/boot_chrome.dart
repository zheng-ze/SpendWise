import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/stats_screen.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

class BootChrome extends ConsumerWidget {
  const BootChrome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appPhaseProvider)) {
      Loading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      Failed(:final error) => _LoadFailure(error: error),
      Ready() => const AppShell(
        bodies: {
          ShellDestination.transactions: _buildTransactionsTab,
          ShellDestination.stats: _buildStatsTab,
          ShellDestination.accounts: _buildAccountsTab,
          ShellDestination.settings: _buildSettingsTab,
        },
      ),
    };
  }
}

Widget _buildTransactionsTab(BuildContext context) => const TransactionsFlow();

Widget _buildStatsTab(BuildContext context) => const StatsScreen();

Widget _buildAccountsTab(BuildContext context) => const AccountsFlow();

Widget _buildSettingsTab(BuildContext context) => const SettingsFlow();

class _LoadFailure extends ConsumerWidget {
  const _LoadFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Logged only, since the screen below deliberately withholds this
    // developer-facing detail from the user.
    debugPrint('AppBoot failed to load: $error');

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Couldn't load your data",
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                // The raw exception stays out of this widget entirely and
                // reaches only whatever logs `error` above.
                'Something went wrong loading your data. Please try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.read(appBootProvider).retry(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
