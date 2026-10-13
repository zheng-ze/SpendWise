part of '../sync_enrollment_screens.dart';

// MARK: - Completion Screen

class SyncEnrollmentCompletionScreen extends ConsumerWidget {
  const SyncEnrollmentCompletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncEnrollmentViewModel viewModel = ref.watch(
      syncEnrollmentViewModelProvider.notifier,
    );
    final SyncEnrollmentState state = ref.watch(
      syncEnrollmentViewModelProvider,
    );
    if (!state.repairMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sync enrolled')),
        body: Padding(
          padding: _screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sync enrollment complete'),
              const SizedBox(height: _sectionSpacing),
              FilledButton(
                key: const Key('syncFreshDone'),
                onPressed: viewModel.dismissFlow,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Repair Device Access')),
      body: ListView(
        padding: _screenPadding,
        children: [
          const Text('Device access restored'),
          const Text('Sync writes have resumed.'),
          const SizedBox(height: _sectionSpacing),
          FilledButton(
            key: const Key('syncRepairDone'),
            onPressed: viewModel.dismissRepairFlow,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
