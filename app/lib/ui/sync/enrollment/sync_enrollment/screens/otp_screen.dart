part of '../sync_enrollment_screens.dart';

// MARK: - OTP Screen

class SyncOtpScreen extends ConsumerStatefulWidget {
  const SyncOtpScreen({super.key});

  @override
  ConsumerState<SyncOtpScreen> createState() => _SyncOtpScreenState();
}

class _SyncOtpScreenState extends ConsumerState<SyncOtpScreen> {
  late final TextEditingController _otpController = TextEditingController();
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
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
    final action = state.inFlight
        ? const SizedBox.square(
            dimension: _progressIndicatorSize,
            child: CircularProgressIndicator(strokeWidth: _progressStrokeWidth),
          )
        : const Text('Verify code');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        viewModel.cancelOtp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enter verification code'),
          leading: BackButton(
            key: const Key('syncOtpBack'),
            onPressed: viewModel.cancelOtp,
          ),
        ),
        body: ListView(
          padding: _screenPadding,
          children: [
            Text('A six-digit code was sent to ${state.identifier}.'),
            const SizedBox(height: _sectionSpacing),
            TextField(
              key: const Key('syncOtpField'),
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                hintText: '482916',
              ),
              keyboardType: TextInputType.number,
              autocorrect: false,
              onSubmitted: viewModel.submitOtp,
            ),
            if (state.explainCodeReplacement)
              const Padding(
                padding: _notePadding,
                child: Text('Requesting a new code replaces the previous one.'),
              ),
            if (errorMessage != null)
              SyncEnrollmentErrorText(message: errorMessage),
            const SizedBox(height: _sectionSpacing),
            FilledButton(
              key: const Key('syncOtpSubmit'),
              onPressed: () => viewModel.submitOtp(_otpController.text),
              child: action,
            ),
            TextButton(
              key: const Key('syncOtpNewCode'),
              onPressed: cooldown == null && state.otpWaiting
                  ? () => viewModel.requestNewCode()
                  : null,
              child: Text(
                cooldown == null
                    ? 'Send a new code'
                    : 'Send a new code in ${_ceilCooldownSeconds(cooldown)}s',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
