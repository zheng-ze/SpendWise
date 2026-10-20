import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

class BackendPickerFlow extends FlowBase<BackendPickerStep> {
  const BackendPickerFlow({
    super.key,
    super.onEnded,
    required this.onHostedReady,
  });

  final VoidCallback onHostedReady;

  @override
  ConsumerState<BackendPickerFlow> createState() => _BackendPickerFlowState();
}

class _BackendPickerFlowState
    extends FlowBaseState<BackendPickerStep, BackendPickerFlow> {
  // The save cannot be cancelled, so exiting mid-save would persist a
  // backend choice from an abandoned enrollment.
  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(
      backendPickerViewModelProvider.select((state) => state.saving),
    );
    // NavigatorPopHandler only passes a root pop through and cannot block it, and
    // goBack's saving guard is bypassed by root system Back, so this keeps the
    // rule that the flow cannot be left while saving.
    return PopScope(canPop: !saving, child: super.build(context));
  }

  @override
  Future<void> goBack() async {
    if (ref.read(backendPickerViewModelProvider).saving) return;
    await super.goBack();
  }

  @override
  void Function() subscribeToStep(
    void Function(BackendPickerStep? step) handle,
  ) => ref
      .listenManual(
        backendPickerViewModelProvider,
        (previous, BackendPickerState next) => handle(next.step),
      )
      .close;

  @override
  void handleStep(BuildContext context, BackendPickerStep step) {
    switch (step) {
      case HostedReady():
        widget.onHostedReady();
      case CustomEndpointUnavailable():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom servers are not yet available.'),
          ),
        );
    }
    ref.read(backendPickerViewModelProvider.notifier).clearStep();
  }

  @override
  Widget buildRoot(BuildContext context) =>
      BackendPickerScreen(onBack: showsOwnBackButton ? goBack : null);
}
