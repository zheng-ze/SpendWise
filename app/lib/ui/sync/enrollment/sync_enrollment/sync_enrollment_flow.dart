import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_flow.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';

class SyncEnrollmentFlow extends FlowBase<SyncEnrollmentStep> {
  const SyncEnrollmentFlow({super.key, super.onEnded, this.repairMode = false});

  final bool repairMode;

  @override
  ConsumerState<SyncEnrollmentFlow> createState() => _SyncEnrollmentFlowState();
}

class _SyncEnrollmentFlowState
    extends FlowBaseState<SyncEnrollmentStep, SyncEnrollmentFlow> {
  late final SyncEnrollmentNotifier _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(syncEnrollmentViewModelProvider.notifier);
    if (widget.repairMode) {
      // enterRepairMode writes provider state, illegal inside initState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_enterRepair());
      });
    }
  }

  Future<void> _enterRepair() async {
    final repairNeeded = await _viewModel.enterRepairMode();
    if (!mounted) return;
    if (repairNeeded == false) {
      try {
        await ref.read(appBootProvider).refreshSyncStatus();
      } catch (_) {}
      if (!mounted) return;
      widget.onEnded?.call();
    }
  }

  @override
  void dispose() {
    _viewModel.cancelPendingOperation();
    super.dispose();
  }

  @override
  Future<void> goBack() async {
    if (ref.read(backendPickerViewModelProvider).saving) return;
    await super.goBack();
  }

  @override
  void Function() subscribeToStep(
    void Function(SyncEnrollmentStep? step) handle,
  ) => ref
      .listenManual(
        syncEnrollmentViewModelProvider,
        (previous, SyncEnrollmentState next) => handle(next.step),
      )
      .close;

  @override
  void handleStep(BuildContext context, SyncEnrollmentStep step) {
    final navigator = Navigator.of(context);
    switch (step) {
      case ShowIdentifierEntry():
        // The repair root already is identifier entry.
        navigator.popUntil((route) => route.isFirst);
        if (!widget.repairMode) {
          navigator.push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'sync-identifier'),
              builder: (_) => const SyncIdentifierScreen(),
            ),
          );
        }
      case ShowOtpEntry():
        navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'sync-otp'),
            builder: (_) => const SyncOtpScreen(),
          ),
        );
      case ShowProgressResume():
        navigator.popUntil((route) => route.isFirst);
        navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'sync-resume'),
            builder: (_) => const SyncEnrollmentResumeScreen(),
          ),
        );
      case ShowEnrollmentCompleted():
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'sync-complete'),
            builder: (_) => const SyncEnrollmentCompletionScreen(),
          ),
          (_) => false,
        );
      case DismissEnrollmentFlow():
        unawaited(goBack());
    }
    _viewModel.clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) => widget.repairMode
      ? const SyncIdentifierScreen()
      : BackendPickerFlow(
          onEnded: widget.onEnded,
          onHostedReady: _viewModel.hostedReady,
        );
}
