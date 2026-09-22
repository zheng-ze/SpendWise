import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

/// Owns the backend-picker step of enrollment in its own nested Navigator.
///
/// A hosted selection ends by invoking [onHostedReady] for the future caller
/// to continue enrollment; this Flow owns no routes beyond the picker itself.
/// A custom selection has no backend behind it yet, so the Flow keeps the
/// picker on screen with a not-yet-available affordance instead of advancing.
class BackendPickerFlow extends FlowBase<BackendPickerStep> {
  const BackendPickerFlow({
    super.key,
    super.onEnded,
    required this.onHostedReady,
  });

  /// Continuation a future caller consumes once the hosted choice persists.
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
