import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
  late final StateController<bool> _repairFlowOpen;
  bool _ownsRepairRoute = false;
  void Function()? _closeSelectionSubscription;

  @override
  void initState() {
    super.initState();
    _repairFlowOpen = ref.read(repairFlowOpenProvider.notifier);
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
    _markRepairRouteClosed();
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
    // Two Flow instances coexist while AppShell switches layouts and both see
    // the same request; the shared flag lets exactly one of them push.
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

  Future<void> _refreshSyncStatus() async {
    try {
      await ref.read(appBootProvider).refreshSyncStatus();
    } catch (_) {}
  }

  @override
  Widget buildRoot(BuildContext context) => const SettingsScreen();
}
