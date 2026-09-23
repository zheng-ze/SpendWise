import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';

class SyncIdentifierScreen extends ConsumerStatefulWidget {
  const SyncIdentifierScreen({super.key});

  @override
  ConsumerState<SyncIdentifierScreen> createState() =>
      _SyncIdentifierScreenState();
}

class _SyncIdentifierScreenState extends ConsumerState<SyncIdentifierScreen> {
  late final TextEditingController _identifierController;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: ref.read(syncEnrollmentViewModelProvider).identifier,
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
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
    final action = state.inFlight
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('Continue');

    return PopScope(
      canPop: !state.inFlight,
      child: Scaffold(
        appBar: AppBar(title: const Text('Hosted sync sign-in')),
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
            if (errorMessage != null)
              SyncEnrollmentErrorText(message: errorMessage),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('syncIdentifierContinue'),
              onPressed: state.inFlight
                  ? null
                  : () =>
                        viewModel.submitIdentifier(_identifierController.text),
              child: action,
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

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
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
            if (errorMessage != null)
              SyncEnrollmentErrorText(message: errorMessage),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('syncOtpSubmit'),
              onPressed: () => viewModel.submitOtp(_otpController.text),
              child: action,
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
