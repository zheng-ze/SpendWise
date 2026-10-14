import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/spendwise_wordmark.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - BootChrome
class BootChrome extends ConsumerWidget {
  const BootChrome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appPhaseProvider)) {
      Loading() => const _BootLoading(),
      Failed(:final error) => _LoadFailure(error: error),
      Ready() => AppShell(
        moneySourceId: () => ref.read(moneyNavigatorObserverProvider).sourceId,
        bodies: {
          ShellDestination.overview: _buildOverviewTab,
          ShellDestination.history: _buildHistoryTab,
          ShellDestination.trends: _buildTrendsTab,
          ShellDestination.money: (context) => AccountsFlow(
            moneyObserver: ref.read(moneyNavigatorObserverProvider),
          ),
          ShellDestination.settings: _buildSettingsTab,
        },
      ),
    };
  }
}

Widget _buildOverviewTab(BuildContext context) => const _OverviewTabEntry();

// MARK: - Constants
const _overviewBackLabel = 'Overview';
const _bootPagePadding = EdgeInsets.all(30);
const _bootContentGap = 14.0;
const _bootWordmarkFontSize = 26.0;
const _progressSize = 30.0;
const _progressStrokeWidth = 3.0;
const _loadingSemanticsLabel = 'Loading your data';
const _failureTitle = "Couldn't load your data";
const _failureMessage =
    'Something went wrong loading your data. Please try again.';
const _retryLabel = 'Retry';
const _failureTitleFontSize = 18.0;
const _failureTitleWeight = FontWeight.w600;
const _failureMessageFontSize = 12.0;
const _retryWidth = double.infinity;

// MARK: - OverviewTabEntry
class _OverviewTabEntry extends ConsumerWidget {
  const _OverviewTabEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(shellLayoutModeProvider) == ShellLayoutMode.phone) {
      return OverviewFlow(historyRouteBuilder: _buildHistoryPage);
    }
    return OverviewFlow(
      onHistorySelected: () =>
          ref.read(selectedDestinationProvider.notifier).state =
              ShellDestination.history,
    );
  }
}

// MARK: - Tab Builders
Widget _buildHistoryPage(BuildContext routeContext) => TransactionsFlow(
  backLabel: _overviewBackLabel,
  onEnded: () => Navigator.of(routeContext).pop(),
);

// MARK: - HistoryTabEntry
class _HistoryTabEntry extends ConsumerWidget {
  const _HistoryTabEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(shellLayoutModeProvider) == ShellLayoutMode.phone) {
      return TransactionsFlow(
        backLabel: _overviewBackLabel,
        onEnded: () => ref.read(selectedDestinationProvider.notifier).state =
            ShellDestination.overview,
      );
    }
    return const TransactionsFlow();
  }
}

Widget _buildHistoryTab(BuildContext context) => const _HistoryTabEntry();

Widget _buildTrendsTab(BuildContext context) => const StatsFlow();

Widget _buildSettingsTab(BuildContext context) => const SettingsFlow();

// MARK: - BootLoading
class _BootLoading extends StatelessWidget {
  const _BootLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.base,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: _bootPagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpendWiseWordmark(fontSize: _bootWordmarkFontSize),
                  const SizedBox(height: _bootContentGap),
                  SizedBox(
                    width: _progressSize,
                    height: _progressSize,
                    child: CircularProgressIndicator(
                      strokeWidth: _progressStrokeWidth,
                      backgroundColor: colors.surface,
                      color: colors.action,
                      semanticsLabel: _loadingSemanticsLabel,
                    ),
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

// MARK: - LoadFailure
class _LoadFailure extends ConsumerWidget {
  const _LoadFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;

    debugPrint('AppBoot failed to load: $error');

    return Scaffold(
      backgroundColor: colors.base,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: _bootPagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpendWiseWordmark(fontSize: _bootWordmarkFontSize),
                  const SizedBox(height: _bootContentGap),
                  Text(
                    _failureTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: _failureTitleFontSize,
                      fontWeight: _failureTitleWeight,
                      color: colors.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: _bootContentGap),
                  Text(
                    _failureMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: _failureMessageFontSize,
                      color: colors.subtext,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: _bootContentGap),
                  SizedBox(
                    width: _retryWidth,
                    child: FilledButton(
                      onPressed: () => ref.read(appBootProvider).retry(),
                      child: const Text(_retryLabel),
                    ),
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
