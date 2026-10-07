import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _bannerElevation = 3.0;

class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  static const _messageBackgroundOpacity = 0.92;

  static const _messagePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(hostedSyncStatusProvider);
    final repairFlowVisible =
        ref.watch(enrollmentFlowOpenProvider) &&
        ref.watch(selectedDestinationProvider) == ShellDestination.settings;
    final needsRepair =
        status is HostedSyncBindingRepair || status is HostedSyncSessionReauth;
    if (needsRepair && !repairFlowVisible) return const _RepairBanner();

    final message = ref.watch(bannerStateProvider).message;
    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return _BottomAnchored(
      horizontalInset: 0,
      child: Center(
        child: Material(
          color: theme.colorScheme.inverseSurface.withValues(
            alpha: _messageBackgroundOpacity,
          ),
          shape: const StadiumBorder(),
          elevation: _bannerElevation,
          child: Padding(
            padding: _messagePadding,
            child: Text(
              message,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onInverseSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The rail layout has no bottom bar to consume the system inset.
class _BottomAnchored extends StatelessWidget {
  const _BottomAnchored({required this.horizontalInset, required this.child});

  final double horizontalInset;
  final Widget child;

  static const _safeAreaBottomMargin = EdgeInsets.only(bottom: 16);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: horizontalInset,
      right: horizontalInset,
      bottom: 0,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: _safeAreaBottomMargin,
        child: child,
      ),
    );
  }
}

// Takes precedence over BannerState's timed messages, which return once repair
// clears.
class _RepairBanner extends ConsumerWidget {
  const _RepairBanner();

  static const _cornerRadius = 16.0;

  static const _contentPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static const _iconTextGap = 12.0;

  static const _horizontalInset = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onErrorContainer;

    void openRepair() {
      ref.read(selectedDestinationProvider.notifier).state =
          ShellDestination.settings;
      if (!ref.read(enrollmentFlowOpenProvider)) {
        ref.read(settingsRootViewModelProvider.notifier).requestRepair();
      }
    }

    final banner = Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(_cornerRadius),
      elevation: _bannerElevation,
      child: InkWell(
        borderRadius: BorderRadius.circular(_cornerRadius),
        onTap: openRepair,
        child: Padding(
          padding: _contentPadding,
          child: Row(
            children: [
              Icon(Icons.warning_outlined, color: foreground),
              const SizedBox(width: _iconTextGap),
              Expanded(
                child: Text(
                  'Sync needs attention - Repair Device Access',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: foreground),
            ],
          ),
        ),
      ),
    );

    return _BottomAnchored(
      horizontalInset: _horizontalInset,
      child: MergeSemantics(child: Semantics(button: true, child: banner)),
    );
  }
}
