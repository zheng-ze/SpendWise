import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_screen.dart';
import 'package:spendwise/ui/settings/settings_root_screen.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';

class SettingsFlow extends FlowBase<SettingsStep> {
  const SettingsFlow({super.key});

  @override
  ConsumerState<SettingsFlow> createState() => _SettingsFlowState();
}

class _SettingsFlowState extends FlowBaseState<SettingsStep, SettingsFlow> {
  late final StateController<bool> _repairFlowOpen;
  late final ProviderContainer _container;
  bool _ownsRepairRoute = false;
  void Function()? _closeSelectionSubscription;

  @override
  void initState() {
    super.initState();
    _repairFlowOpen = ref.read(repairFlowOpenProvider.notifier);
    _container = ProviderScope.containerOf(context, listen: false);
    // AppShell keeps every destination mounted, so the cached status must be
    // re-read when the Settings tab is selected.
    if (ref.read(selectedDestinationProvider) == ShellDestination.settings) {
      unawaited(_refreshSyncStatus());
    }
    // FlowBase drops steps emitted before the navigator mounts, so re-check
    // the pending step once mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = navigatorContext;
      if (context == null) return;
      final step = ref.read(settingsRootViewModelProvider).step;
      if (step != null) handleStep(context, step);
    });
    _closeSelectionSubscription = ref.listenManual(
      selectedDestinationProvider,
      (previous, next) {
        if (previous != ShellDestination.settings &&
            next == ShellDestination.settings) {
          unawaited(_refreshSyncStatus());
        }
      },
    ).close;
  }

  @override
  void dispose() {
    _closeSelectionSubscription?.call();
    _handOverOpenRepairRoute();
    super.dispose();
  }

  @override
  void Function() subscribeToStep(void Function(SettingsStep? step) handle) =>
      ref
          .listenManual(
            settingsRootViewModelProvider,
            (previous, SettingsRootViewState next) => handle(next.step),
          )
          .close;

  @override
  void handleStep(BuildContext context, SettingsStep step) {
    switch (step) {
      case CategoriesRequested():
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CategoryListScreen()),
        );
      case PlansRequested():
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PlanListScreen()));
      case RecycleBinRequested():
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RecycleBinScreen()),
        );
      case RepairDeviceAccessRequested():
        _openRepairFlow(context);
    }
    ref.read(settingsRootViewModelProvider.notifier).clearStep();
  }

  void _openRepairFlow(BuildContext context) {
    // Two Flows coexist during an AppShell layout switch; the shared flag lets
    // only one push.
    if (_repairFlowOpen.state) return;
    _repairFlowOpen.state = true;
    _ownsRepairRoute = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SyncEnrollmentFlow(
              repairMode: true,
              onEnded: () => Navigator.of(context).pop(),
            ),
          ),
        )
        .then((_) async {
          _markRepairRouteClosed();
          if (!mounted) return;
          await _refreshSyncStatus();
        });
  }

  void _markRepairRouteClosed() {
    if (!_ownsRepairRoute) return;
    _ownsRepairRoute = false;
    if (_repairFlowOpen.mounted) _repairFlowOpen.state = false;
  }

  // Disposing the Flow destroys its repair route, so a surviving Flow must
  // reopen it. Provider writes are illegal while the tree finalizes, hence the
  // microtask.
  void _handOverOpenRepairRoute() {
    if (!_ownsRepairRoute) return;
    _ownsRepairRoute = false;
    final repairFlowOpen = _repairFlowOpen;
    final container = _container;
    scheduleMicrotask(() {
      if (!repairFlowOpen.mounted) return;
      repairFlowOpen.state = false;
      final status = container.read(hostedSyncStatusProvider);
      final needsRepair =
          status is HostedSyncBindingRepair ||
          status is HostedSyncSessionReauth;
      if (!needsRepair) return;
      container.read(settingsRootViewModelProvider.notifier).requestRepair();
    });
  }

  Future<void> _refreshSyncStatus() async {
    try {
      await ref.read(appBootProvider).refreshSyncStatus();
    } catch (_) {}
  }

  @override
  Widget buildRoot(BuildContext context) => const SettingsScreen();
}
