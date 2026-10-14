import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

// MARK: - Constants
const _bannerElevation = 3.0;
const _messageHorizontalInset = 0.0;
const _bannerBottom = 0.0;

// MARK: - StatusBanner
class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key, this.rightGutter = 0});

  final double rightGutter;

  static const _messageBackgroundOpacity = 0.92;

  static const _messagePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(hostedSyncStatusProvider);
    final repairFlowVisible =
        ref.watch(selectedDestinationProvider) == ShellDestination.settings &&
        ref.watch(enrollmentFlowOpenProvider);
    final needsRepair =
        status is HostedSyncBindingRepair || status is HostedSyncSessionReauth;
    if (needsRepair && !repairFlowVisible) {
      return _RepairBanner(rightGutter: rightGutter);
    }

    final message = ref.watch(bannerStateProvider).message;
    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return _BottomAnchored(
      left: _messageHorizontalInset,
      right: _messageHorizontalInset + rightGutter,
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

// MARK: - BottomAnchored
// The rail layout has no bottom bar to consume the system inset.
class _BottomAnchored extends StatelessWidget {
  const _BottomAnchored({
    required this.left,
    required this.right,
    required this.child,
  });

  final double left;
  final double right;
  final Widget child;

  static const _safeAreaBottomMargin = EdgeInsets.only(bottom: 16);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      bottom: _bannerBottom,
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

// MARK: - RepairBanner
// Takes precedence over BannerState's timed messages, which return once repair
// clears.
class _RepairBanner extends ConsumerWidget {
  const _RepairBanner({required this.rightGutter});

  final double rightGutter;

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
      left: _horizontalInset,
      right: _horizontalInset + rightGutter,
      child: MergeSemantics(child: Semantics(button: true, child: banner)),
    );
  }
}
