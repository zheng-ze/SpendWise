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
        ? const InlineSpinner()
        : const Text(loadErrorRetryLabel);

    final header = PageHeader(
      title: state.repairMode
          ? 'Repair Device Access'
          : 'Finishing sync enrollment',
      onBack: () => Navigator.of(context).maybePop(),
    );
    final content = ListView(
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
    );
    final page = Column(
      children: [
        header,
        Expanded(child: content),
      ],
    );

    return PopScope(
      canPop: !state.repairMode || !state.inFlight,
      child: Scaffold(body: SafeArea(child: page)),
    );
  }
}
