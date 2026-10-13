part of '../sync_enrollment_screens.dart';

// MARK: - Resume Screen

class SyncEnrollmentResumeScreen extends ConsumerWidget {
  const SyncEnrollmentResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncEnrollmentViewModel viewModel = ref.watch(
      syncEnrollmentViewModelProvider.notifier,
    );
    final SyncEnrollmentState state = ref.watch(
      syncEnrollmentViewModelProvider,
    );
    final errorMessage = state.errorMessage;
    final status =
        errorMessage ??
        (state.repairMode
            ? 'Restoring device access. '
                  'Reconciling and publishing this device. Keep the app open.'
            : 'Finishing hosted sync enrollment.');
    final action = state.inFlight
        ? const SizedBox.square(
            dimension: _progressIndicatorSize,
            child: CircularProgressIndicator(strokeWidth: _progressStrokeWidth),
          )
        : const Text('Retry');

    return PopScope(
      // Repair publishing must not be popped mid-flight.
      canPop: !state.repairMode || !state.inFlight,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            state.repairMode
                ? 'Repair Device Access'
                : 'Finishing sync enrollment',
          ),
        ),
        body: ListView(
          padding: _screenPadding,
          children: [
            Text(status),
            const SizedBox(height: _sectionSpacing),
            FilledButton(
              key: const Key('syncResumeRetry'),
              onPressed: state.inFlight ? null : viewModel.retry,
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}
