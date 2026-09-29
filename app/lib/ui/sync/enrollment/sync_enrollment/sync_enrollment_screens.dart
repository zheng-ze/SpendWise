import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';

int _ceilCooldownSeconds(Duration remaining) {
  final seconds = (remaining.inMilliseconds / 1000).ceil();
  return seconds < 1 ? 1 : seconds;
}

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

  // Ticks only while a code-request cooldown is active so the countdown text
  // stays live; with no cooldown no timer exists and frame settling is
  // unaffected.
  void _syncCooldownTimer(Duration? remaining) {
    if (remaining == null) {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
      return;
    }
    _cooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
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
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Continue');

    return PopScope(
      canPop: !state.inFlight,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            state.repairMode ? 'Repair Device Access' : 'Hosted sync sign-in',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Enter the email address used for hosted sync. '
              'A one-time code will be sent to it.',
            ),
            const SizedBox(height: 16),
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
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Requesting a new code replaces the previous one. '
                  'Only the newest code will work.',
                ),
              ),
            if (errorMessage != null)
              SyncEnrollmentErrorText(message: errorMessage),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('syncIdentifierContinue'),
              onPressed: state.inFlight || cooldown != null
                  ? null
                  : () =>
                        viewModel.submitIdentifier(_identifierController.text),
              child: action,
            ),
            if (countdown != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(countdown),
              ),
          ],
        ),
      ),
    );
  }
}

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

  // Ticks only while a code-request cooldown is active so the countdown text
  // stays live; with no cooldown no timer exists and frame settling is
  // unaffected.
  void _syncCooldownTimer(Duration? remaining) {
    if (remaining == null) {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
      return;
    }
    _cooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
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
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
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
          padding: const EdgeInsets.all(16),
          children: [
            Text('A six-digit code was sent to ${state.identifier}.'),
            const SizedBox(height: 16),
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
                padding: EdgeInsets.only(top: 12),
                child: Text('Requesting a new code replaces the previous one.'),
              ),
            if (errorMessage != null)
              SyncEnrollmentErrorText(message: errorMessage),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('syncOtpSubmit'),
              onPressed: () => viewModel.submitOtp(_otpController.text),
              child: action,
            ),
            TextButton(
              key: const Key('syncOtpNewCode'),
              onPressed: cooldown == null
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
    final status = errorMessage ?? 'Finishing hosted sync enrollment.';
    final action = state.inFlight
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Retry');

    return Scaffold(
      appBar: AppBar(title: const Text('Finishing sync enrollment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(status),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('syncResumeRetry'),
            onPressed: state.inFlight ? null : viewModel.retry,
            child: action,
          ),
        ],
      ),
    );
  }
}

class SyncEnrollmentCompletionScreen extends StatelessWidget {
  const SyncEnrollmentCompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync enrolled')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sync enrollment complete'),
      ),
    );
  }
}

class SyncEnrollmentErrorText extends StatelessWidget {
  const SyncEnrollmentErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(message, style: TextStyle(color: colors.error)),
    );
  }
}
