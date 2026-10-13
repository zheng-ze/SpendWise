part of '../sync_enrollment_screens.dart';

// MARK: - Identifier Screen

class SyncIdentifierScreen extends ConsumerStatefulWidget {
  const SyncIdentifierScreen({super.key});

  @override
  ConsumerState<SyncIdentifierScreen> createState() =>
      _SyncIdentifierScreenState();
}

class _SyncIdentifierScreenState extends ConsumerState<SyncIdentifierScreen> {
  late final TextEditingController _identifierController;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: ref.read(syncEnrollmentViewModelProvider).identifier,
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _identifierController.dispose();
    super.dispose();
  }

  void _syncCooldownTimer(Duration? remaining) {
    if (remaining == null) {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
      return;
    }
    _cooldownTimer ??= Timer.periodic(_cooldownTick, (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final SyncEnrollmentViewModel viewModel = ref.watch(
      syncEnrollmentViewModelProvider.notifier,
    );
    final SyncEnrollmentState state = ref.watch(
      syncEnrollmentViewModelProvider,
    );
    final errorMessage = state.errorMessage;
    final cooldown = viewModel.codeCooldownRemaining();
    _syncCooldownTimer(cooldown);
    final countdown = cooldown == null
        ? null
        : 'Send a new code in ${_ceilCooldownSeconds(cooldown)}s';
    final action = state.inFlight
        ? const SizedBox.square(
            dimension: _progressIndicatorSize,
            child: CircularProgressIndicator(strokeWidth: _progressStrokeWidth),
          )
        : const Text('Continue');

    return PopScope(
      canPop: state.repairMode || !state.inFlight,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            state.repairMode ? 'Repair Device Access' : 'Hosted sync sign-in',
          ),
        ),
        body: ListView(
          padding: _screenPadding,
          children: [
            const Text(
              'Enter the email address used for hosted sync. '
              'A one-time code will be sent to it.',
            ),
            const SizedBox(height: _sectionSpacing),
            TextField(
              key: const Key('syncIdentifierField'),
              controller: _identifierController,
              enabled: !state.inFlight,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onSubmitted: (_) =>
                  viewModel.submitIdentifier(_identifierController.text),
            ),
            if (state.explainCodeReplacement)
              const Padding(
                padding: _notePadding,
                child: Text(
                  'Requesting a new code replaces the previous one. '
                  'Only the newest code will work.',
                ),
              ),
            if (errorMessage != null)
              SyncEnrollmentErrorText(message: errorMessage),
            const SizedBox(height: _sectionSpacing),
            FilledButton(
              key: const Key('syncIdentifierContinue'),
              onPressed: state.inFlight || cooldown != null
                  ? null
                  : () =>
                        viewModel.submitIdentifier(_identifierController.text),
              child: action,
            ),
            if (countdown != null)
              Padding(padding: _notePadding, child: Text(countdown)),
          ],
        ),
      ),
    );
  }
}
