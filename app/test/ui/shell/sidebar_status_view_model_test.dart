import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/shell/sidebar_status_view_model.dart';

// MARK: - Constants
const _statusLabels = <(HostedSyncStatus, String)>[
  (HostedSyncNoSelection(), 'Sync not configured'),
  (HostedSyncSetupPending(), 'Sync setup pending'),
  (HostedSyncReady(), 'Sync ready'),
  (HostedSyncBindingRepair(), 'Device access needs repair'),
  (HostedSyncSessionReauth(), 'Sign in to restore sync'),
  (HostedSyncUnsupportedV2(), 'Custom sync unsupported'),
  (HostedSyncUnavailable(), 'Sync unavailable'),
];

void main() {
  test('projects every hosted sync status to its sidebar label', () {
    for (final (status, label) in _statusLabels) {
      final container = ProviderContainer(
        overrides: [hostedSyncStatusProvider.overrideWithValue(status)],
      );
      addTearDown(container.dispose);

      expect(container.read(sidebarStatusViewModelProvider).syncLabel, label);
    }
  });
}
