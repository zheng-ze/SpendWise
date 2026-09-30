import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_enrollment_session.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
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

class DismissEnrollmentFlow extends SyncEnrollmentStep {}

final class DismissRepairFlow extends DismissEnrollmentFlow {}

enum FreshEntryResult { applied, superseded }

final class SyncEnrollmentState
    implements HasStep<SyncEnrollmentState, SyncEnrollmentStep> {
  const SyncEnrollmentState({
    this.identifier = '',
    this.inFlight = false,
    this.errorMessage,
    this.cancelled = false,
    this.step,
    this.repairMode = false,
    this.repairPhase,
    this.explainCodeReplacement = false,
    this.codeCooldownEndsAt,
    this.otpWaiting = false,
  });

  final String identifier;
  final bool inFlight;
  final String? errorMessage;
  final bool cancelled;

  @override
  final SyncEnrollmentStep? step;

  final bool repairMode;
  final SyncEnrollmentPhase? repairPhase;
  final bool explainCodeReplacement;
  final DateTime? codeCooldownEndsAt;

  /// True while exactly one OTP resolver waits for input.
  final bool otpWaiting;

  SyncEnrollmentState copyWith({
    String? identifier,
    bool? inFlight,
    String? Function()? errorMessage,
    bool? cancelled,
    SyncEnrollmentStep? Function()? step,
    bool? repairMode,
    SyncEnrollmentPhase? Function()? repairPhase,
    bool? explainCodeReplacement,
    DateTime? Function()? codeCooldownEndsAt,
    bool? otpWaiting,
  }) {
    return SyncEnrollmentState(
      identifier: identifier ?? this.identifier,
      inFlight: inFlight ?? this.inFlight,
      errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
      cancelled: cancelled ?? this.cancelled,
      step: step == null ? this.step : step(),
      repairMode: repairMode ?? this.repairMode,
      repairPhase: repairPhase == null ? this.repairPhase : repairPhase(),
      explainCodeReplacement:
          explainCodeReplacement ?? this.explainCodeReplacement,
      codeCooldownEndsAt: codeCooldownEndsAt == null
          ? this.codeCooldownEndsAt
          : codeCooldownEndsAt(),
      otpWaiting: otpWaiting ?? this.otpWaiting,
    );
  }

  @override
  SyncEnrollmentState withStep(SyncEnrollmentStep? Function() step) =>
      copyWith(step: step);
}

abstract class SyncEnrollmentViewModel {
  void hostedReady();
  Future<FreshEntryResult> enterFreshMode();
  Future<void> submitIdentifier(String identifier);
  void submitOtp(String otp);
  void cancelOtp();

  Future<void> requestNewCode();
  Duration? codeCooldownRemaining();
  void dismissRepairFlow();
  void dismissFlow();
  void cancelPendingOperation();
  Future<void> retry();
  void clearStep();
}

final class _EnrollmentOperation {
  bool cancelled = false;
  bool otpAccepted = false;

  void cancel() => cancelled = true;
}

class SyncEnrollmentNotifier extends Notifier<SyncEnrollmentState>
    with StepEmitting<SyncEnrollmentState, SyncEnrollmentStep>
    implements SyncEnrollmentViewModel {
  SyncEnrollmentNotifier({
    SyncEnrollmentSessionOpener? sessionOpener,
    SecretStore? secretStore,
    this._repairMode = false,
    DateTime Function()? now,
  }) : _sessionOpenerOverride = sessionOpener,
       _secretStore = secretStore ?? SecureSecretStore(),
       _now = now ?? DateTime.now;

  static const maxPublishAttempts = 3;
  static const _publishRetryDelay = Duration(seconds: 1);
  static const codeRequestCooldown = Duration(seconds: 60);
  static const _maxWaitDisplay = Duration(minutes: 15);

  final SyncEnrollmentSessionOpener? _sessionOpenerOverride;
  final SecretStore _secretStore;
  bool _repairMode;
  final DateTime Function() _now;
  Completer<String>? _otpCompleter;
  SyncEnrollmentSession? _session;
  _EnrollmentOperation? _currentOperation;
  Future<void>? _abandonedPublication;
  int _pendingEnrolls = 0;
  final List<Future<void>> _pendingSettlements = [];

  /// Latest mode entry. Each fresh or repair entry claims a new id; a fresh
  /// entry whose wait ends under an older id belongs to a closed route and
  /// must not reset the state owned by the newer entry.
  int _modeSequence = 0;

  @override
  SyncEnrollmentState build() => SyncEnrollmentState(repairMode: _repairMode);

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
        secretStore: _secretStore,
      );

  @override
  void hostedReady() {
    if (state.inFlight) return;
    state = state.copyWith(errorMessage: () => null, cancelled: false);
    emitStep(ShowIdentifierEntry());
  }

  /// Null when a newer operation superseded this read and owns the outcome.
  Future<bool?> enterRepairMode() {
    final settlement = _enterRepairMode();
    final tracked = settlement.then<void>((_) {}, onError: (_) {});
    _pendingSettlements.add(tracked);
    return settlement.whenComplete(() => _pendingSettlements.remove(tracked));
  }

  Future<bool?> _enterRepairMode() async {
    _modeSequence++;
    if (state.inFlight) return state.repairPhase != null;
    _repairMode = true;
    final operation = _EnrollmentOperation();
    _currentOperation = operation;
    _session = null;
    state = state.copyWith(
      identifier: '',
      errorMessage: () => null,
      cancelled: false,
      repairMode: true,
      explainCodeReplacement: true,
      inFlight: true,
      step: () => null,
    );
    final SyncEnrollmentPhase phase;
    try {
      phase = await _currentPhase();
    } catch (_) {
      if (identical(operation, _currentOperation) && ref.mounted) {
        state = state.copyWith(inFlight: false);
      }
      return false;
    }
    if (!ref.mounted || !identical(operation, _currentOperation)) return null;
    state = state.copyWith(inFlight: false);
    if (_isRepairPhase(phase)) {
      state = state.copyWith(repairPhase: () => phase);
    }
    emitStep(ShowIdentifierEntry());
    return _isRepairPhase(phase);
  }

  @override
  Future<FreshEntryResult> enterFreshMode() async {
    // A prior operation still owns shared enrollment state; the reset below
    // waits for its enrollment, publication, and status refresh to settle.
    // Cancellation already detached those operations from the UI, so their
    // late results cannot navigate or write state for the abandoned route.
    final entryId = ++_modeSequence;
    while (state.inFlight ||
        _pendingEnrolls > 0 ||
        _abandonedPublication != null ||
        _pendingSettlements.isNotEmpty) {
      final abandoned = _abandonedPublication;
      final waiting = <Future<void>>[..._pendingSettlements, ?abandoned];
      if (waiting.isEmpty) {
        await Future<void>.delayed(Duration.zero);
        continue;
      }
      for (final pending in waiting) {
        try {
          await pending;
        } catch (_) {}
      }
    }
    // A newer mode entry or route closure superseded this entry while it
    // waited; its reset must not touch the state the newer entry owns.
    if (!ref.mounted || entryId != _modeSequence) {
      return FreshEntryResult.superseded;
    }
    _repairMode = false;
    _currentOperation = null;
    _session = null;
    state = state.copyWith(
      errorMessage: () => null,
      cancelled: false,
      step: () => null,
      repairMode: false,
      repairPhase: () => null,
      explainCodeReplacement: false,
      otpWaiting: false,
    );
    return FreshEntryResult.applied;
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
    final cooldown = _codeCooldownRemaining();
    if (cooldown != null) {
      state = state.copyWith(errorMessage: () => _cooldownCopy(cooldown));
      return;
    }
    final operation = _EnrollmentOperation();
    _currentOperation = operation;
    _session = null;
    state = state.copyWith(
      identifier: trimmed,
      inFlight: true,
      errorMessage: () => null,
      cancelled: false,
    );
    final settlement = _submitAfterIdentifier(trimmed, operation);
    _pendingSettlements.add(settlement);
    try {
      await settlement;
    } finally {
      _pendingSettlements.remove(settlement);
    }
  }

  Future<void> _submitAfterIdentifier(
    String identifier,
    _EnrollmentOperation operation,
  ) async {
    try {
      await _abandonedPublication;
      if (!identical(operation, _currentOperation)) return;
      await _enrollFromIdentifier(identifier, operation);
    } finally {
      if (identical(operation, _currentOperation) && ref.mounted) {
        state = state.copyWith(inFlight: false);
      }
    }
    if (ref.mounted) await _refreshSyncStatus();
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
    state = state.copyWith(errorMessage: () => null, otpWaiting: false);
    _otpCompleter = null;
    final acceptedOperation = _currentOperation;
    if (_repairMode && acceptedOperation != null) {
      acceptedOperation.otpAccepted = true;
      emitStep(ShowProgressResume());
    }
    pending.complete(trimmed);
  }

  @override
  void cancelOtp() {
    final pending = _otpCompleter;
    if (pending == null || pending.isCompleted) return;
    _otpCompleter = null;
    state = state.copyWith(otpWaiting: false);
    pending.completeError(const SyncEnrollmentOtpCancelled());
  }

  @override
  Future<void> requestNewCode() async {
    // Only one OTP resolver waiting means repeated taps cannot stack sessions.
    final waiting = _otpCompleter;
    if (waiting == null || waiting.isCompleted) return;
    final cooldown = _codeCooldownRemaining();
    if (cooldown != null) {
      state = state.copyWith(errorMessage: () => _cooldownCopy(cooldown));
      return;
    }
    final identifier = state.identifier.trim();
    if (identifier.isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Enter the email address used for hosted sync.',
      );
      return;
    }
    // The next challenge must push the only OTP route.
    cancelPendingOperation();
    emitStep(ShowIdentifierEntry());
    state = state.copyWith(inFlight: false, otpWaiting: false);
    await submitIdentifier(identifier);
  }

  @override
  Duration? codeCooldownRemaining() => _codeCooldownRemaining();

  @override
  void dismissRepairFlow() => emitStep(DismissRepairFlow());

  @override
  void dismissFlow() => emitStep(DismissEnrollmentFlow());

  @override
  void cancelPendingOperation() {
    final operation = _currentOperation;
    final cancelsAcceptedOtp =
        operation != null && operation.otpAccepted && state.inFlight;
    operation?.cancel();
    _currentOperation = null;
    // A disposed route no longer owns its pending fresh entry; a newer mode
    // entry already superseded it or will claim the next id.
    _modeSequence++;
    final pending = _otpCompleter;
    _otpCompleter = null;
    _session = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const SyncEnrollmentOtpCancelled());
    }
    // The Flow calls this while the tree finalizes, so provider writes must be
    // deferred.
    if (ref.mounted) {
      scheduleMicrotask(() {
        if (!ref.mounted || _currentOperation != null) return;
        if (cancelsAcceptedOtp && _repairMode) {
          emitStep(ShowOtpEntry());
        }
        state = state.copyWith(inFlight: false, otpWaiting: false);
      });
    }
  }

  @override
  Future<void> retry() async {
    if (state.inFlight) return;
    final operation = _EnrollmentOperation();
    _currentOperation = operation;
    state = state.copyWith(
      inFlight: true,
      errorMessage: () => null,
      cancelled: false,
    );
    final settlement = _retryAfterStart(operation);
    _pendingSettlements.add(settlement);
    try {
      await settlement;
    } finally {
      _pendingSettlements.remove(settlement);
    }
  }

  Future<void> _retryAfterStart(_EnrollmentOperation operation) async {
    try {
      await _abandonedPublication;
      final phase = await _currentPhase();
      if (!ref.mounted || !identical(operation, _currentOperation)) return;
      if (phase == SyncEnrollmentPhase.notEnrolled || _isRepairPhase(phase)) {
        if (_repairMode && _isRepairPhase(phase)) {
          state = state.copyWith(repairPhase: () => phase);
        }
        emitStep(ShowIdentifierEntry());
        return;
      }
      emitStep(ShowProgressResume());
      await _resumeWithoutCredentials(operation);
    } finally {
      if (identical(operation, _currentOperation) && ref.mounted) {
        state = state.copyWith(inFlight: false);
      }
    }
    if (ref.mounted) await _refreshSyncStatus();
  }

  Future<void> _enrollFromIdentifier(
    String identifier,
    _EnrollmentOperation operation,
  ) async {
    Future<String> resolveOtp(EnrollmentChallenge challenge) {
      if (!identical(operation, _currentOperation) || operation.cancelled) {
        throw const SyncEnrollmentOtpCancelled();
      }
      // The challenge issues the code, so the cooldown starts here.
      _noteCodeRequested();
      final otpCompleter = Completer<String>();
      _otpCompleter = otpCompleter;
      if (_repairMode) {
        state = state.copyWith(explainCodeReplacement: true, otpWaiting: true);
      } else {
        state = state.copyWith(otpWaiting: true);
      }
      emitStep(ShowOtpEntry());
      return otpCompleter.future;
    }

    final SyncEnrollmentSessionResult? result = await _openSession(
      identifier: identifier,
      resolveOtp: resolveOtp,
      operation: operation,
    );
    if (!ref.mounted ||
        !identical(operation, _currentOperation) ||
        result == null) {
      return;
    }
    if (result is SyncEnrollmentSessionNotReady) {
      state = state.copyWith(
        errorMessage: () =>
            'Sync is not ready yet. Finish app start, then try again.',
      );
      return;
    }
    if (result is SyncEnrollmentSessionConfigurationError) {
      state = state.copyWith(
        errorMessage: () =>
            'Hosted sync is not available right now. Please try again later.',
      );
      return;
    }
    final session = (result as SyncEnrollmentSessionReady).session;
    _session = session;
    if (_repairMode) {
      await _refreshRepairPhase(operation);
      if (!ref.mounted || !identical(operation, _currentOperation)) return;
    }
    try {
      _pendingEnrolls++;
      await session.enroll();
    } on SyncEnrollmentOtpCancelled {
      _enterCancelled(operation);
      return;
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
      return;
    } finally {
      _pendingEnrolls--;
    }
    if (!ref.mounted) return;
    if (!identical(operation, _currentOperation)) {
      if (_repairMode && _currentOperation == null) {
        await _publishAbandonedRepairProof(session);
      }
      return;
    }
    if (_repairMode) {
      await _completeRepairIfProofPresent(session, operation);
      return;
    }
    await _publishUntilPublished(session, operation);
  }

  // The Flow can close after OTP acceptance while the service still stores its
  // write proof; publish it here since no UI remains to retry. New operations
  // wait for it because sessions share one proof key.
  Future<void> _publishAbandonedRepairProof(SyncEnrollmentSession session) {
    final publication = _runAbandonedPublication(session);
    _abandonedPublication = publication;
    return publication.whenComplete(() {
      if (identical(_abandonedPublication, publication)) {
        _abandonedPublication = null;
      }
    });
  }

  Future<void> _runAbandonedPublication(SyncEnrollmentSession session) async {
    try {
      final proof = await _secretStore.read(syncWriteProofSecretKey);
      if (proof != null && proof.isNotEmpty) {
        for (var attempt = 1; attempt <= maxPublishAttempts; attempt++) {
          final outcome = await session.publishSnapshot();
          if (outcome is EnrollmentSnapshotPublished) break;
          if (attempt == maxPublishAttempts) break;
          await Future<void>.delayed(_publishRetryDelay);
        }
      }
    } on Object catch (_) {
      // No UI remains to surface the failure; the proof stays stored.
    }
    if (ref.mounted) await _refreshSyncStatus();
  }

  Future<void> _resumeWithoutCredentials(_EnrollmentOperation operation) async {
    final session = _session ?? await _reopenForResume(operation);
    if (!ref.mounted ||
        !identical(operation, _currentOperation) ||
        session == null) {
      return;
    }
    _session = session;
    try {
      await session.enroll();
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
      return;
    }
    if (!ref.mounted || !identical(operation, _currentOperation)) return;
    if (_repairMode) {
      await _completeRepairIfProofPresent(session, operation);
      return;
    }
    await _publishUntilPublished(session, operation);
  }

  Future<SyncEnrollmentSession?> _reopenForResume(
    _EnrollmentOperation operation,
  ) async {
    final result = await _openSession(
      identifier: state.identifier,
      resolveOtp: _rejectUnexpectedOtp,
      operation: operation,
    );
    if (!ref.mounted ||
        !identical(operation, _currentOperation) ||
        result == null) {
      return null;
    }
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
          'Hosted sync is not available right now. Please try again later.',
    );
    return null;
  }

  static Future<String> _rejectUnexpectedOtp(EnrollmentChallenge challenge) =>
      throw StateError(
        'OTP is not collected when resuming from a durable phase.',
      );

  Future<SyncEnrollmentSessionResult?> _openSession({
    required String identifier,
    required Future<String> Function(EnrollmentChallenge challenge) resolveOtp,
    required _EnrollmentOperation operation,
  }) async {
    try {
      return await _opener(identifier: identifier, resolveOtp: resolveOtp);
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
      return null;
    }
  }

  Future<void> _completeRepairIfProofPresent(
    SyncEnrollmentSession session,
    _EnrollmentOperation operation,
  ) async {
    final String? proof;
    try {
      proof = await _secretStore.read(syncWriteProofSecretKey);
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
      return;
    }
    if (!ref.mounted || !identical(operation, _currentOperation)) return;
    if (proof == null || proof.isEmpty) {
      state = state.copyWith(errorMessage: () => null);
      emitStep(ShowEnrollmentCompleted());
      return;
    }
    await _publishUntilPublished(session, operation);
  }

  Future<void> _publishUntilPublished(
    SyncEnrollmentSession session,
    _EnrollmentOperation operation,
  ) async {
    var attempts = 0;
    try {
      while (true) {
        final outcome = await session.publishSnapshot();
        if (!ref.mounted || !identical(operation, _currentOperation)) return;
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
            operation,
          );
          return;
        }
        await Future<void>.delayed(_publishRetryDelay);
        if (!ref.mounted || !identical(operation, _currentOperation)) return;
      }
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
    }
  }

  void _enterCancelled(_EnrollmentOperation operation) {
    if (!identical(operation, _currentOperation)) return;
    _otpCompleter = null;
    _session = null;
    state = state.copyWith(
      errorMessage: () => null,
      cancelled: true,
      otpWaiting: false,
    );
    emitStep(ShowIdentifierEntry());
  }

  Future<void> _failPhaseAware(
    Object error,
    _EnrollmentOperation operation,
  ) async {
    if (!identical(operation, _currentOperation)) return;
    final message = _failureCopy(error);
    _extendCooldownFrom(error, operation);
    final phase = await _currentPhase();
    if (!ref.mounted || !identical(operation, _currentOperation)) return;
    state = state.copyWith(
      errorMessage: () => message,
      repairPhase: _repairMode && _isRepairPhase(phase) ? () => phase : null,
    );
    if (phase == SyncEnrollmentPhase.notEnrolled || _isRepairPhase(phase)) {
      emitStep(ShowIdentifierEntry());
    } else {
      emitStep(ShowProgressResume());
    }
  }

  Future<void> _refreshRepairPhase(_EnrollmentOperation operation) async {
    final phase = await _currentPhase();
    if (!ref.mounted || !identical(operation, _currentOperation)) return;
    if (_isRepairPhase(phase)) {
      state = state.copyWith(repairPhase: () => phase);
    }
  }

  Future<void> _refreshSyncStatus() async {
    try {
      await ref.read(appBootProvider).refreshSyncStatus();
    } catch (_) {}
  }

  Future<SyncEnrollmentPhase> _currentPhase() async {
    final snapshot = await ref.read(syncMetadataStoreProvider).snapshot();
    return snapshot.phase;
  }

  static bool _isRepairPhase(SyncEnrollmentPhase phase) =>
      phase == SyncEnrollmentPhase.bindingAuthorizationRequired ||
      phase == SyncEnrollmentPhase.sessionReauthRequired;

  Duration? _codeCooldownRemaining() {
    final endsAt = state.codeCooldownEndsAt;
    if (endsAt == null) return null;
    final remaining = endsAt.difference(_now());
    return remaining.isNegative ? null : remaining;
  }

  void _noteCodeRequested() {
    if (!ref.mounted) return;
    state = state.copyWith(
      codeCooldownEndsAt: () => _now().add(codeRequestCooldown),
    );
  }

  void _extendCooldownFrom(Object error, _EnrollmentOperation operation) {
    if (!identical(operation, _currentOperation)) return;
    final retryAfter = error is SyncEnrollmentException
        ? error.retryAfter
        : null;
    if (retryAfter == null) return;
    final candidate = _now().add(retryAfter);
    final current = state.codeCooldownEndsAt;
    if (current == null || candidate.isAfter(current)) {
      state = state.copyWith(codeCooldownEndsAt: () => candidate);
    }
  }

  static int _ceilSeconds(Duration remaining) {
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    return seconds < 1 ? 1 : seconds;
  }

  String _failureCopy(Object error) {
    if (error is SyncEnrollmentException) {
      final base = _copyForCode(error.code);
      final retryAfter = error.retryAfter;
      if (retryAfter == null) return base;
      return '$base ${_waitCopy(retryAfter)}';
    }
    return _repairMode
        ? 'Repair failed. Please try again.'
        : 'Enrollment failed. Please try again.';
  }

  String _copyForCode(String code) {
    switch (code) {
      case 'rate_limited':
        return 'Too many codes were requested.';
      case 'invalid_request':
        return _repairMode
            ? 'The code was not accepted. Enter the latest code from your email.'
            : 'The request was not accepted. Please try again.';
      case 'credential_expired':
        return 'The sign-in expired. Enter your email to get a new code.';
      case 'device_authorization_required':
        return 'This device needs authorization again. '
            'Enter your email to get a new code.';
      case 'network_unavailable':
      case 'backend_unavailable':
        return 'The sync service is unreachable. '
            'Check your connection and try again.';
      case 'incompatible_server':
      case 'protocol_unsupported':
        return 'Hosted sync is temporarily unavailable. '
            'Please try again later.';
      case 'snapshotPending':
        return 'Snapshot publication is still pending. Please retry.';
      default:
        return _repairMode
            ? 'Repair failed. Please try again.'
            : 'Enrollment failed. Please try again.';
    }
  }

  static String _cooldownCopy(Duration remaining) => remaining > _maxWaitDisplay
      ? _waitCopy(remaining)
      : 'Send a new code in ${_ceilSeconds(remaining)}s.';

  static String _waitCopy(Duration retryAfter) {
    final seconds = retryAfter.inSeconds;
    final capped = seconds > _maxWaitDisplay.inSeconds
        ? _maxWaitDisplay.inSeconds
        : seconds;
    if (capped <= 0) {
      return 'Please wait a moment before trying again.';
    }
    if (capped < 60) {
      return 'Please wait $capped seconds before trying again.';
    }
    final minutes = capped ~/ 60;
    if (minutes <= 1) {
      return 'Please wait about a minute before trying again.';
    }
    return 'Please wait about $minutes minutes before trying again.';
  }
}

final syncEnrollmentViewModelProvider =
    NotifierProvider<SyncEnrollmentNotifier, SyncEnrollmentState>(
      SyncEnrollmentNotifier.new,
    );
