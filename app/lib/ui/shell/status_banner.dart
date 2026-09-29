import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

class StatusBanner extends ConsumerWidget {
  const StatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(hostedSyncStatusProvider);
    final repairFlowOpen = ref.watch(repairFlowOpenProvider);
    final needsRepair =
        status is HostedSyncBindingRepair || status is HostedSyncSessionReauth;
    if (needsRepair && !repairFlowOpen) return const _RepairBanner();

    final message = ref.watch(bannerStateProvider).message;
    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return _BottomAnchored(
      horizontalInset: 0,
      child: Center(
        child: Material(
          color: theme.colorScheme.inverseSurface.withValues(alpha: 0.92),
          shape: const StadiumBorder(),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

// Rail layout has no bottom bar to consume the system inset, so the banner
// sits above it with a 16 dp minimum gap.
class _BottomAnchored extends StatelessWidget {
  const _BottomAnchored({required this.horizontalInset, required this.child});

  final double horizontalInset;
  final Widget child;

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
        minimum: const EdgeInsets.only(bottom: 16),
        child: child,
      ),
    );
  }
}

// Persistent repair action. It takes precedence over BannerState's timed
// messages, which stay in their state and return once repair clears. It steps
// aside while the repair route is open so it cannot cover the form's controls.
class _RepairBanner extends ConsumerWidget {
  const _RepairBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onErrorContainer;

    void openRepair() {
      ref.read(selectedDestinationProvider.notifier).state =
          ShellDestination.settings;
      ref.read(settingsRootViewModelProvider.notifier).requestRepair();
    }

    final banner = Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: openRepair,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.warning_outlined, color: foreground),
              const SizedBox(width: 12),
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
      horizontalInset: 16,
      child: MergeSemantics(child: Semantics(button: true, child: banner)),
    );
  }
}
