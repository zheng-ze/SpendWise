import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/lists/section_label.dart';
import 'package:spendwise/ui/common/navigation/page_header.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/theme/edge_border.dart';

// MARK: - SettingsScreen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _screenTitle = 'Settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(settingsRootViewModelProvider.notifier);
    final scanStripEnabled = ref.watch(scanStripEnabledProvider);

    final list = ListView(
      children: [
        const SectionLabel('Manage', padding: _headerPadding),
        _SettingsLink(
          icon: Icons.sell_outlined,
          label: 'Categories',
          onTap: viewModel.requestCategories,
        ),
        const Divider(height: edgeThickness),
        const SectionLabel('Receipt Scanning', padding: _headerPadding),
        SwitchListTile(
          secondary: const Icon(Icons.document_scanner_outlined),
          title: const Text('Show scan/upload on new entry'),
          value: scanStripEnabled.value ?? true,
          onChanged: (value) async {
            await ref.read(appSettingsProvider).setScanStripEnabled(value);
            ref.invalidate(scanStripEnabledProvider);
          },
        ),
        const Divider(height: edgeThickness),
        const SectionLabel('Currency', padding: _headerPadding),
        const ListTile(
          leading: Icon(Icons.attach_money),
          title: Text('Currency'),
          subtitle: Text('Amounts display in Singapore dollars'),
          trailing: Text('SGD'),
        ),
        const Divider(height: edgeThickness),
        const SectionLabel('Data', padding: _headerPadding),
        _SettingsLink(
          icon: Icons.delete_outline,
          label: 'Recycle Bin',
          onTap: viewModel.requestRecycleBin,
        ),
      ],
    );
    final page = Column(
      children: [
        const PageHeader(title: _screenTitle),
        Expanded(child: list),
      ],
    );
    return Scaffold(body: SafeArea(child: page));
  }
}

const _headerPadding = EdgeInsets.fromLTRB(16, 16, 16, 4);

// MARK: - SettingsLink
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
