import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';

// MARK: - Constants
const _syncNotConfiguredLabel = 'Sync not configured';
const _syncSetupPendingLabel = 'Sync setup pending';
const _syncReadyLabel = 'Sync ready';
const _deviceAccessRepairLabel = 'Device access needs repair';
const _signInToRestoreSyncLabel = 'Sign in to restore sync';
const _customSyncUnsupportedLabel = 'Custom sync unsupported';
const _syncUnavailableLabel = 'Sync unavailable';

// MARK: - SidebarStatusViewModel
abstract class SidebarStatusViewModel {
  String get syncLabel;
}

class _SidebarStatusViewModel implements SidebarStatusViewModel {
  const _SidebarStatusViewModel(this.status);

  final HostedSyncStatus status;

  @override
  String get syncLabel => switch (status) {
    HostedSyncNoSelection() => _syncNotConfiguredLabel,
    HostedSyncSetupPending() => _syncSetupPendingLabel,
    HostedSyncReady() => _syncReadyLabel,
    HostedSyncBindingRepair() => _deviceAccessRepairLabel,
    HostedSyncSessionReauth() => _signInToRestoreSyncLabel,
    HostedSyncUnsupportedV2() => _customSyncUnsupportedLabel,
    HostedSyncUnavailable() => _syncUnavailableLabel,
  };
}

// MARK: - Providers
final sidebarStatusViewModelProvider = Provider<SidebarStatusViewModel>(
  (ref) => _SidebarStatusViewModel(ref.watch(hostedSyncStatusProvider)),
);
