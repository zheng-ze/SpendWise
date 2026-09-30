import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(settingsRootViewModelProvider.notifier);
    final scanStripEnabled = ref.watch(scanStripEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: ListView(
        children: [
          const _SectionHeader('Manage'),
          _SettingsLink(
            icon: Icons.sell_outlined,
            label: 'Categories',
            onTap: viewModel.requestCategories,
          ),
          _SettingsLink(
            icon: Icons.repeat,
            label: 'Recurring Plans',
            onTap: viewModel.requestPlans,
          ),
          const Divider(height: 1),
          const _SectionHeader('Hosted Sync'),
          const _HostedSyncSection(),
          const Divider(height: 1),
          const _SectionHeader('Receipt Scanning'),
          SwitchListTile(
            secondary: const Icon(Icons.document_scanner_outlined),
            title: const Text('Show scan/upload on new entry'),
            value: scanStripEnabled.value ?? true,
            onChanged: (value) async {
              await ref.read(appSettingsProvider).setScanStripEnabled(value);
              ref.invalidate(scanStripEnabledProvider);
            },
          ),
          const Divider(height: 1),
          const _SectionHeader('Data'),
          _SettingsLink(
            icon: Icons.delete_outline,
            label: 'Recycle Bin',
            onTap: viewModel.requestRecycleBin,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _HostedSyncSection extends ConsumerWidget {
  const _HostedSyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(hostedSyncStatusProvider);
    final viewModel = ref.watch(settingsRootViewModelProvider.notifier);
    final explanation = _hostedSyncExplanation(status);
    final statusLines = <Widget>[Text(_hostedSyncStatusText(status))];
    if (explanation != null) statusLines.add(Text(explanation));
    final canStartEnrollment =
        status is HostedSyncNoSelection || status is HostedSyncSetupPending;

    final tiles = <Widget>[
      ListTile(
        key: const Key('hostedSyncStatus'),
        leading: const Icon(Icons.cloud_outlined),
        title: const Text('Hosted sync'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: statusLines,
        ),
        trailing: canStartEnrollment ? const Icon(Icons.chevron_right) : null,
        onTap: canStartEnrollment
            ? viewModel.requestStartHostedEnrollment
            : null,
      ),
    ];
    if (status is HostedSyncBindingRepair ||
        status is HostedSyncSessionReauth) {
      final primary = Theme.of(context).colorScheme.primary;
      tiles.add(
        ListTile(
          key: const Key('repairDeviceAccess'),
          leading: const Icon(Icons.refresh),
          title: const Text('Repair Device Access'),
          trailing: const Icon(Icons.chevron_right),
          iconColor: primary,
          textColor: primary,
          onTap: viewModel.requestRepair,
        ),
      );
    }
    return Column(children: tiles);
  }
}

String _hostedSyncStatusText(HostedSyncStatus status) => switch (status) {
  HostedSyncNoSelection() => 'Not configured',
  HostedSyncSetupPending() => 'Setup pending',
  HostedSyncReady() => 'Ready',
  HostedSyncBindingRepair() => 'Binding repair needed',
  HostedSyncSessionReauth() => 'Sign-in expired',
  HostedSyncUnsupportedV2() => 'Unsupported endpoint',
  HostedSyncUnavailable() => 'Status unavailable',
};

String? _hostedSyncExplanation(HostedSyncStatus status) => switch (status) {
  HostedSyncBindingRepair() =>
    'Device access must be authorized again. '
        'Reconciliation will run before sync writes resume.',
  HostedSyncSessionReauth() =>
    'Your sync sign-in expired. Existing device access will be kept.',
  HostedSyncUnsupportedV2() =>
    'Custom endpoints are not supported by sync protocol v2.',
  HostedSyncUnavailable() => 'Sync status could not be read.',
  _ => null,
};
