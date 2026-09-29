import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
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
  bool _repairFlowOpen = false;
  void Function()? _closeSelectionSubscription;

  @override
  void initState() {
    super.initState();
    // AppShell keeps every destination mounted in an IndexedStack, so a
    // cached status would otherwise survive until the next repair return.
    // Re-read durable metadata whenever the Settings tab becomes selected.
    if (ref.read(selectedDestinationProvider) == ShellDestination.settings) {
      unawaited(_refreshSyncStatus());
    }
    // The repair banner can emit its single-shot request before this Flow's
    // navigator mounts, and FlowBase drops pre-mount steps. Re-check the
    // pending step once mounted so the request is consumed exactly once.
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
    if (_repairFlowOpen) return;
    _repairFlowOpen = true;
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
          _repairFlowOpen = false;
          if (!mounted) return;
          await _refreshSyncStatus();
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
