import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/spendwise_wordmark.dart';
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
        moneySourceId: ref.read(activeMoneySourceProvider),
        bodies: {
          ShellDestination.overview: _buildOverviewTab,
          ShellDestination.history: _buildHistoryTab,
          ShellDestination.money: (_) => const MoneyFlow(),
          ShellDestination.settings: _buildSettingsTab,
        },
      ),
    };
  }
}

Widget _buildOverviewTab(BuildContext context) => const _OverviewTabEntry();

// MARK: - Constants
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
    return OverviewFlow(
      onHistorySelected: () =>
          ref.read(selectedDestinationProvider.notifier).state =
              ShellDestination.history,
    );
  }
}

// MARK: - Tab Builders
Widget _buildHistoryTab(BuildContext context) => const TransactionsFlow();

Widget _buildSettingsTab(BuildContext context) => const SettingsFlow();

// MARK: - BootPage
class _BootPage extends StatelessWidget {
  const _BootPage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final content = _BootContent(children: children);

    return Scaffold(
      backgroundColor: context.colors.base,
      body: SafeArea(child: content),
    );
  }
}

class _BootContent extends StatelessWidget {
  const _BootContent({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final column = Column(mainAxisSize: MainAxisSize.min, children: children);
    final padded = Padding(padding: _bootPagePadding, child: column);

    return Center(child: SingleChildScrollView(child: padded));
  }
}

// MARK: - BootLoading
class _BootLoading extends StatelessWidget {
  const _BootLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final progress = CircularProgressIndicator(
      strokeWidth: _progressStrokeWidth,
      backgroundColor: colors.surface,
      color: colors.action,
      semanticsLabel: _loadingSemanticsLabel,
    );
    final sizedProgress = SizedBox(
      width: _progressSize,
      height: _progressSize,
      child: progress,
    );

    return _BootPage(
      children: [
        const SpendWiseWordmark(fontSize: _bootWordmarkFontSize),
        const SizedBox(height: _bootContentGap),
        sizedProgress,
      ],
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

    final title = Text(
      _failureTitle,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontSize: _failureTitleFontSize,
        fontWeight: _failureTitleWeight,
        color: colors.text,
      ),
      textAlign: TextAlign.center,
    );
    final message = Text(
      _failureMessage,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: _failureMessageFontSize,
        color: colors.subtext,
      ),
      textAlign: TextAlign.center,
    );
    final retryButton = FilledButton(
      onPressed: () => ref.read(appBootProvider).retry(),
      child: const Text(_retryLabel),
    );
    final retry = SizedBox(width: _retryWidth, child: retryButton);

    return _BootPage(
      children: [
        const SpendWiseWordmark(fontSize: _bootWordmarkFontSize),
        const SizedBox(height: _bootContentGap),
        title,
        const SizedBox(height: _bootContentGap),
        message,
        const SizedBox(height: _bootContentGap),
        retry,
      ],
    );
  }
}
