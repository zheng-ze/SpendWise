import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

/// A custom selection builds no backend; the picker stays on screen with a
/// not-yet-available affordance instead of advancing.
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
  Widget buildRoot(BuildContext context) => const BackendPickerScreen();
}
