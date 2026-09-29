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
    if (status is HostedSyncBindingRepair ||
        status is HostedSyncSessionReauth) {
      return const _RepairBanner();
    }

    final message = ref.watch(bannerStateProvider).message;
    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
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

// Persistent repair action. It takes precedence over BannerState's timed
// messages, which stay in their state and return once repair clears.
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

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: MergeSemantics(child: Semantics(button: true, child: banner)),
    );
  }
}
