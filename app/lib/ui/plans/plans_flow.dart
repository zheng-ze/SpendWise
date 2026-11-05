import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/feedback/destructive_confirmation.dart';
import 'package:spendwise/ui/common/layout/headered_page.dart';
import 'package:spendwise/ui/plans/plan_detail_screen.dart';
import 'package:spendwise/ui/plans/plan_detail_view_model.dart';
import 'package:spendwise/ui/plans/plan_selection.dart';
import 'package:spendwise/ui/plans/plan_steps.dart';
import 'package:spendwise/ui/plans/plans_list_view.dart';
import 'package:spendwise/ui/shell/selected_detail_controller.dart';

// MARK: - Constants
const _deleteBodyText = 'Entries it already added stay in History.';

// MARK: - PlansFlow
class PlansFlow extends FlowBase<PlanDetailStep> {
  const PlansFlow({super.key, required this.header});

  final Widget header;

  @override
  ConsumerState<PlansFlow> createState() => _PlansFlowState();
}

// MARK: - PlansFlowState
class _PlansFlowState extends FlowBaseState<PlanDetailStep, PlansFlow> {
  late final SelectedDetailController _detail = SelectedDetailController(
    ref: ref,
    selection: selectedPlanProvider,
    clearSelection: () => ref.read(selectedPlanProvider.notifier).clear(),
    buildPage: _buildDetailPage,
    navigatorContext: () => navigatorContext,
    mounted: () => mounted,
    openOwners: _openOwners,
    onShownChanged: (_) {},
  );

  void Function(PlanDetailStep? step)? _forwardStep;

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _detail.start();
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  ModalRoute<Object?> _buildDetailPage(String planID) =>
      MaterialPageRoute<Object?>(
        builder: (_) => PlanDetailScreen(planID: planID),
      );

  // MARK: - Plan Subscriptions

  List<ProviderSubscription<Object?>> _openOwners(String planID) {
    final detail = ref.listenManual(planDetailViewModelProvider(planID), (
      _,
      next,
    ) {
      _clearSelectionWhenMissing(planID, next.value?.phase);
      _forwardStep?.call(next.value?.step);
    });
    return [detail];
  }

  void _clearSelectionWhenMissing(String planID, PlanDetailPhase? phase) {
    if (phase != PlanDetailPhase.deleted) return;
    if (_detail.shownID != planID) return;
    ref.read(selectedPlanProvider.notifier).clear();
  }

  // MARK: - Steps

  @override
  void Function() subscribeToStep(void Function(PlanDetailStep? step) handle) {
    _forwardStep = handle;
    return () => _forwardStep = null;
  }

  @override
  void handleStep(BuildContext context, PlanDetailStep step) {
    final planID = _detail.shownID;
    if (planID == null) return;
    ref.read(planDetailViewModelProvider(planID).notifier).clearStep();
    switch (step) {
      case PlanDeleteRequested():
        unawaited(_confirmDelete(context, planID));
    }
  }

  Future<void> _confirmDelete(BuildContext context, String planID) async {
    final name = ref.read(planDetailViewModelProvider(planID)).value?.name;
    final ledger = ref.read(ledgerProvider);
    if (name == null || ledger == null) return;

    final confirmed = await showDestructiveConfirmation(
      context,
      title: 'Delete the $name plan?',
      body: _deleteBodyText,
    );
    if (!confirmed || !_deleteStillValid(planID, ledger)) return;
    ref.read(planDetailViewModelProvider(planID).notifier).deletePlan();
    ref.read(selectedPlanProvider.notifier).clear();
    _detail.reconcileNow();
  }

  bool _deleteStillValid(String planID, Ledger ledger) {
    if (!mounted || _detail.shownID != planID) return false;
    if (!identical(ref.read(ledgerProvider), ledger)) return false;
    return ledger.state.plans.containsKey(planID);
  }

  @override
  Widget buildRoot(BuildContext context) =>
      HeaderedPage(header: widget.header, body: const PlansRoot());
}
