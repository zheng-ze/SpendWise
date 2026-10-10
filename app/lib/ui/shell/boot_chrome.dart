import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
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
        },
      ),
    };
  }
}

Widget _buildTransactionsTab(BuildContext context) => const TransactionsFlow();

Widget _buildStatsTab(BuildContext context) => const StatsFlow();

Widget _buildAccountsTab(BuildContext context) => const AccountsFlow();

class _LoadFailure extends ConsumerWidget {
  const _LoadFailure({required this.error});

  final Object error;

  static const _pagePadding = EdgeInsets.all(24);

  static const _messageGap = 8.0;

  static const _retryGap = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    debugPrint('AppBoot failed to load: $error');

    return Scaffold(
      body: Center(
        child: Padding(
          padding: _pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Couldn't load your data",
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _messageGap),
              Text(
                'Something went wrong loading your data. Please try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _retryGap),
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
