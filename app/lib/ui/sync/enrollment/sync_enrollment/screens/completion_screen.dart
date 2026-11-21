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
    final header = PageHeader(
      title: state.repairMode ? 'Repair Device Access' : 'Sync enrolled',
      onBack: () => Navigator.of(context).maybePop(),
    );
    final freshContent = Padding(
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
    );
    final repairContent = ListView(
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
    );
    final content = state.repairMode ? repairContent : freshContent;
    final page = Column(
      children: [
        header,
        Expanded(child: content),
      ],
    );

    return Scaffold(body: SafeArea(child: page));
  }
}
