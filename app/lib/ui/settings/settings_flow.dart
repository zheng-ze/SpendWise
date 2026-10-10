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
  const SettingsFlow({super.key, super.onEnded, this.backLabel});

  final String? backLabel;

  @override
  ConsumerState<SettingsFlow> createState() => _SettingsFlowState();
}

class _SettingsFlowState extends FlowBaseState<SettingsStep, SettingsFlow> {
  late final StateController<bool> _enrollmentFlowOpen;
  late final ProviderContainer _container;
  bool _ownsEnrollmentRoute = false;
  bool _ownedRepairRoute = false;
  bool _closedWhileMounted = false;

  @override
  void initState() {
    super.initState();
    _enrollmentFlowOpen = ref.read(enrollmentFlowOpenProvider.notifier);
    _container = ProviderScope.containerOf(context, listen: false);
    ref.listenManual(settingsOpenProvider, (_, open) {
      if (!open) _closedWhileMounted = true;
    });
    unawaited(_refreshSyncStatus());
    // FlowBase drops steps emitted before the navigator mounts, so re-check
    // the pending step once mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = navigatorContext;
      if (context == null) return;
      final step = ref.read(settingsRootViewModelProvider).step;
      if (step != null) handleStep(context, step);
    });
  }

  @override
  void dispose() {
    _settleAtDispose();
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
      case StartHostedEnrollmentRequested():
        _openFreshFlow(context);
      case ResumeFreshEnrollmentRequested():
        _pushEnrollmentRoute(context, repairMode: false);
    }
    ref.read(settingsRootViewModelProvider.notifier).clearStep();
  }

  void _openRepairFlow(BuildContext context) {
    _pushEnrollmentRoute(context, repairMode: true);
  }

  void _openFreshFlow(BuildContext context) {
    final status = _container.read(hostedSyncStatusProvider);
    if (status is! HostedSyncNoSelection && status is! HostedSyncSetupPending) {
      return;
    }
    _pushEnrollmentRoute(context, repairMode: false);
  }

  void _pushEnrollmentRoute(BuildContext context, {required bool repairMode}) {
    // Two Flows coexist during an AppShell layout switch; the shared flag lets
    // only one push.
    if (_enrollmentFlowOpen.state) return;
    _enrollmentFlowOpen.state = true;
    _ownsEnrollmentRoute = true;
    _ownedRepairRoute = repairMode;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SyncEnrollmentFlow(
              repairMode: repairMode,
              onEnded: () => Navigator.of(context).pop(),
            ),
          ),
        )
        .then((_) async {
          _markEnrollmentRouteClosed();
          if (!mounted) return;
          await _refreshSyncStatus();
        });
  }

  void _markEnrollmentRouteClosed() {
    if (!_ownsEnrollmentRoute) return;
    _ownsEnrollmentRoute = false;
    _ownedRepairRoute = false;
    if (_enrollmentFlowOpen.mounted) _enrollmentFlowOpen.state = false;
  }

  // Provider writes are illegal while the tree finalizes, hence the microtask.
  void _settleAtDispose() {
    final ownedRoute = _ownsEnrollmentRoute;
    final ownedRepairRoute = _ownedRepairRoute;
    final closedWhileMounted = _closedWhileMounted;
    _ownsEnrollmentRoute = false;
    _ownedRepairRoute = false;
    final enrollmentFlowOpen = _enrollmentFlowOpen;
    final container = _container;
    scheduleMicrotask(() {
      if (!enrollmentFlowOpen.mounted) return;
      final viewModel = container.read(settingsRootViewModelProvider.notifier);
      if (closedWhileMounted || !container.read(settingsOpenProvider)) {
        if (ownedRoute) enrollmentFlowOpen.state = false;
        viewModel.clearStep();
        return;
      }
      if (!ownedRoute) return;
      enrollmentFlowOpen.state = false;
      final status = container.read(hostedSyncStatusProvider);
      if (!ownedRepairRoute) {
        if (status is HostedSyncReady) return;
        viewModel.requestResumeFreshEnrollment();
        return;
      }
      final needsRepair =
          status is HostedSyncBindingRepair ||
          status is HostedSyncSessionReauth;
      if (!needsRepair) return;
      viewModel.requestRepair();
    });
  }

  Future<void> _refreshSyncStatus() async {
    try {
      await ref.read(appBootProvider).refreshSyncStatus();
    } catch (_) {}
  }

  @override
  Widget buildRoot(BuildContext context) => SettingsScreen(
    backLabel: widget.backLabel,
    onBack: widget.backLabel == null ? null : goBack,
  );
}
