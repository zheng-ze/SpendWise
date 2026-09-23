import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_enrollment_session.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:sync/sync.dart';

final class SyncEnrollmentOtpCancelled implements Exception {
  const SyncEnrollmentOtpCancelled();

  @override
  String toString() => 'SyncEnrollmentOtpCancelled';
}

sealed class SyncEnrollmentStep {}

final class ShowIdentifierEntry extends SyncEnrollmentStep {}

final class ShowOtpEntry extends SyncEnrollmentStep {}

final class ShowProgressResume extends SyncEnrollmentStep {}

final class ShowEnrollmentCompleted extends SyncEnrollmentStep {}

final class SyncEnrollmentState
    implements HasStep<SyncEnrollmentState, SyncEnrollmentStep> {
  const SyncEnrollmentState({
    this.identifier = '',
    this.inFlight = false,
    this.errorMessage,
    this.cancelled = false,
    this.step,
  });

  final String identifier;
  final bool inFlight;
  final String? errorMessage;
  final bool cancelled;

  @override
  final SyncEnrollmentStep? step;

  SyncEnrollmentState copyWith({
    String? identifier,
    bool? inFlight,
    String? Function()? errorMessage,
    bool? cancelled,
    SyncEnrollmentStep? Function()? step,
  }) {
    return SyncEnrollmentState(
      identifier: identifier ?? this.identifier,
      inFlight: inFlight ?? this.inFlight,
      errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
      cancelled: cancelled ?? this.cancelled,
      step: step == null ? this.step : step(),
    );
  }

  @override
  SyncEnrollmentState withStep(SyncEnrollmentStep? Function() step) =>
      copyWith(step: step);
}

abstract class SyncEnrollmentViewModel {
  void hostedReady();
  Future<void> submitIdentifier(String identifier);
  void submitOtp(String otp);
  void cancelOtp();
  Future<void> retry();
  void clearStep();
}

class SyncEnrollmentNotifier extends Notifier<SyncEnrollmentState>
    with StepEmitting<SyncEnrollmentState, SyncEnrollmentStep>
    implements SyncEnrollmentViewModel {
  SyncEnrollmentNotifier({SyncEnrollmentSessionOpener? sessionOpener})
    : _sessionOpenerOverride = sessionOpener;

  static const maxPublishAttempts = 3;
  static const _publishRetryDelay = Duration(seconds: 1);

  final SyncEnrollmentSessionOpener? _sessionOpenerOverride;
  Completer<String>? _otpCompleter;
  SyncEnrollmentSession? _session;

  @override
  SyncEnrollmentState build() => const SyncEnrollmentState();

  @override
  void updateState(
    SyncEnrollmentState Function(SyncEnrollmentState current) apply,
  ) => state = apply(state);

  SyncEnrollmentSessionOpener get _opener =>
      _sessionOpenerOverride ??
      ({required identifier, required resolveOtp}) => openSyncEnrollmentSession(
        ref,
        identifier: identifier,
        resolveOtp: resolveOtp,
      );

  @override
  void hostedReady() {
    if (state.inFlight) return;
    state = state.copyWith(errorMessage: () => null, cancelled: false);
    emitStep(ShowIdentifierEntry());
  }

  @override
  Future<void> submitIdentifier(String identifier) async {
    if (state.inFlight) return;
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Enter the email address used for hosted sync.',
      );
      return;
    }
    state = state.copyWith(
      identifier: trimmed,
      inFlight: true,
      errorMessage: () => null,
      cancelled: false,
    );
    try {
      await _enrollFromIdentifier(trimmed);
    } finally {
      if (ref.mounted) state = state.copyWith(inFlight: false);
    }
  }

  @override
  void submitOtp(String otp) {
    final pending = _otpCompleter;
    if (pending == null || pending.isCompleted) return;
    final trimmed = otp.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Enter the six-digit code sent to your email.',
      );
      return;
    }
    state = state.copyWith(errorMessage: () => null);
    _otpCompleter = null;
    pending.complete(trimmed);
  }

  @override
  void cancelOtp() {
    final pending = _otpCompleter;
    if (pending == null || pending.isCompleted) return;
    _otpCompleter = null;
    pending.completeError(const SyncEnrollmentOtpCancelled());
  }

  @override
  Future<void> retry() async {
    if (state.inFlight) return;
    state = state.copyWith(
      inFlight: true,
      errorMessage: () => null,
      cancelled: false,
    );
    try {
      final phase = await _currentPhase();
      if (!ref.mounted) return;
      if (phase == SyncEnrollmentPhase.notEnrolled) {
        emitStep(ShowIdentifierEntry());
        return;
      }
      emitStep(ShowProgressResume());
      await _resumeWithoutCredentials();
    } finally {
      if (ref.mounted) state = state.copyWith(inFlight: false);
    }
  }

  Future<void> _enrollFromIdentifier(String identifier) async {
    Future<String> resolveOtp(EnrollmentChallenge challenge) {
      final otpCompleter = Completer<String>();
      _otpCompleter = otpCompleter;
      emitStep(ShowOtpEntry());
      return otpCompleter.future;
    }

    final result = await _opener(
      identifier: identifier,
      resolveOtp: resolveOtp,
    );
    if (!ref.mounted) return;
    if (result is SyncEnrollmentSessionNotReady) {
      state = state.copyWith(
        errorMessage: () =>
            'Sync is not ready yet. Finish app start, then try again.',
      );
      return;
    }
    if (result is SyncEnrollmentSessionConfigurationError) {
      state = state.copyWith(errorMessage: () => result.message);
      return;
    }
    final session = (result as SyncEnrollmentSessionReady).session;
    _session = session;
    try {
      await session.enroll();
    } on SyncEnrollmentOtpCancelled {
      _enterCancelled();
      return;
    } on Exception catch (error) {
      await _failPhaseAware(error);
      return;
    }
    if (!ref.mounted) return;
    await _publishUntilPublished(session);
  }

  Future<void> _resumeWithoutCredentials() async {
    final session = _session ?? await _reopenForResume();
    if (!ref.mounted || session == null) return;
    _session = session;
    try {
      await session.enroll();
    } on Exception catch (error) {
      await _failPhaseAware(error);
      return;
    }
    if (!ref.mounted) return;
    await _publishUntilPublished(session);
  }

  Future<SyncEnrollmentSession?> _reopenForResume() async {
    final result = await _opener(
      identifier: state.identifier,
      resolveOtp: _rejectUnexpectedOtp,
    );
    if (!ref.mounted) return null;
    if (result is SyncEnrollmentSessionReady) return result.session;
    if (result is SyncEnrollmentSessionNotReady) {
      state = state.copyWith(
        errorMessage: () =>
            'Sync is not ready yet. Finish app start, then try again.',
      );
      return null;
    }
    state = state.copyWith(
      errorMessage: () =>
          (result as SyncEnrollmentSessionConfigurationError).message,
    );
    return null;
  }

  static Future<String> _rejectUnexpectedOtp(EnrollmentChallenge challenge) =>
      throw StateError(
        'OTP is not collected when resuming from a durable phase.',
      );

  Future<void> _publishUntilPublished(SyncEnrollmentSession session) async {
    var attempts = 0;
    try {
      while (true) {
        final outcome = await session.publishSnapshot();
        if (!ref.mounted) return;
        if (outcome is EnrollmentSnapshotPublished) {
          state = state.copyWith(errorMessage: () => null);
          emitStep(ShowEnrollmentCompleted());
          return;
        }
        attempts += 1;
        if (attempts >= maxPublishAttempts) {
          await _failPhaseAware(
            const SyncEnrollmentException(
              step: 'publishSnapshot',
              code: 'snapshotPending',
              message: 'Snapshot publication is still pending. Please retry.',
            ),
          );
          return;
        }
        await Future<void>.delayed(_publishRetryDelay);
        if (!ref.mounted) return;
      }
    } on StateError catch (error) {
      await _failPhaseAware(error);
    } on Exception catch (error) {
      await _failPhaseAware(error);
    }
  }

  void _enterCancelled() {
    _otpCompleter = null;
    _session = null;
    state = state.copyWith(errorMessage: () => null, cancelled: true);
    emitStep(ShowIdentifierEntry());
  }

  Future<void> _failPhaseAware(Object error) async {
    final message = _describeFailure(error);
    final phase = await _currentPhase();
    if (!ref.mounted) return;
    state = state.copyWith(errorMessage: () => message);
    if (phase == SyncEnrollmentPhase.notEnrolled) {
      emitStep(ShowIdentifierEntry());
    } else {
      emitStep(ShowProgressResume());
    }
  }

  Future<SyncEnrollmentPhase> _currentPhase() async {
    final snapshot = await ref.read(syncMetadataStoreProvider).snapshot();
    return snapshot.phase;
  }

  static String _describeFailure(Object error) {
    if (error is SyncEnrollmentException) {
      final message = error.message;
      if (message != null && message.isNotEmpty) return message;
      return 'Enrollment failed during ${error.step} (${error.code}). '
          'Please try again.';
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Enrollment failed. Please try again.';
  }
}

final syncEnrollmentViewModelProvider =
    NotifierProvider<SyncEnrollmentNotifier, SyncEnrollmentState>(
      SyncEnrollmentNotifier.new,
    );
