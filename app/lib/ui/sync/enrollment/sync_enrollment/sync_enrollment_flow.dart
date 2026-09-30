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
  bool _pickerReady = false;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(syncEnrollmentViewModelProvider.notifier);
    // Provider writes are illegal inside initState, so mode entry runs
    // post-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.repairMode) {
        unawaited(_enterRepair());
      } else {
        unawaited(_enterFresh());
      }
    });
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

  Future<void> _enterFresh() async {
    _viewModel.enterFreshMode();
    final picker = ref.read(backendPickerViewModelProvider.notifier);
    await picker.resetForFreshEntry();
    if (!mounted) return;
    setState(() => _pickerReady = true);
  }

  @override
  void dispose() {
    _viewModel.cancelPendingOperation();
    super.dispose();
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
  Widget buildRoot(BuildContext context) {
    if (widget.repairMode) return const SyncIdentifierScreen();
    if (_pickerReady) {
      return BackendPickerFlow(
        onEnded: widget.onEnded,
        onHostedReady: _viewModel.hostedReady,
      );
    }
    // The picker stays inert until the reset clears any settling save and
    // its step, so a stale HostedReady cannot advance this route.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose sync backend'),
        leading: showsOwnBackButton
            ? BackButton(key: const Key('syncPickerBack'), onPressed: goBack)
            : null,
      ),
    );
  }
}
