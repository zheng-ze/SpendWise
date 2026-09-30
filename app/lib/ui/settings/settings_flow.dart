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
  late final StateController<bool> _enrollmentFlowOpen;
  late final ProviderContainer _container;
  bool _ownsEnrollmentRoute = false;
  bool _ownedRepairRoute = false;
  void Function()? _closeSelectionSubscription;

  @override
  void initState() {
    super.initState();
    _enrollmentFlowOpen = ref.read(enrollmentFlowOpenProvider.notifier);
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
      case StartHostedEnrollmentRequested():
        _openFreshFlow(context);
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

  // Disposing the Flow destroys its enrollment route. A surviving repair
  // Flow must reopen its route, while a fresh route is only released.
  // Provider writes are illegal while the tree finalizes, hence the microtask.
  void _handOverOpenRepairRoute() {
    if (!_ownsEnrollmentRoute) return;
    final ownedRepairRoute = _ownedRepairRoute;
    _ownsEnrollmentRoute = false;
    _ownedRepairRoute = false;
    if (!ownedRepairRoute) {
      final enrollmentFlowOpen = _enrollmentFlowOpen;
      scheduleMicrotask(() {
        if (!enrollmentFlowOpen.mounted) return;
        enrollmentFlowOpen.state = false;
      });
      return;
    }
    final enrollmentFlowOpen = _enrollmentFlowOpen;
    final container = _container;
    scheduleMicrotask(() {
      if (!enrollmentFlowOpen.mounted) return;
      enrollmentFlowOpen.state = false;
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
