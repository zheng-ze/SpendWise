import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_enrollment_session.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:sync/sync.dart';

part 'view_model/sync_enrollment_steps.dart';
part 'view_model/sync_enrollment_state.dart';
part 'view_model/sync_enrollment_contract.dart';
part 'view_model/enrollment_operation.dart';
part 'view_model/enrollment_mode_entry.dart';
part 'view_model/enrollment_identifier_flow.dart';
part 'view_model/enrollment_resume_flow.dart';
part 'view_model/enrollment_publication.dart';
part 'view_model/enrollment_failure_copy.dart';

// MARK: - Enrollment Notifier

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
  static const freshWaitTimeout = Duration(seconds: 30);
  static const _publishRetryDelay = Duration(seconds: 1);
  static const codeRequestCooldown = Duration(seconds: 60);
  static const _maxWaitDisplay = Duration(minutes: 15);

  final SyncEnrollmentSessionOpener? _sessionOpenerOverride;
  final SecretStore _secretStore;
  bool _repairMode;
  final DateTime Function() _now;
  final _operations = _EnrollmentOperations();

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

  // MARK: - Hosted Ready

  @override
  void hostedReady() {
    if (state.inFlight) return;
    state = state.copyWith(errorMessage: () => null, cancelled: false);
    emitStep(ShowIdentifierEntry());
  }

  // MARK: - Fresh Mode

  @override
  Future<FreshEntryResult> enterFreshMode() async {
    final entryId = ++_modeSequence;
    if (_priorOperationPending) {
      try {
        await _settlePriorOperation().timeout(freshWaitTimeout);
      } on TimeoutException {
        if (!ref.mounted || entryId != _modeSequence) {
          return FreshEntryResult.superseded;
        }
        return FreshEntryResult.timedOut;
      }
    }
    if (!ref.mounted || entryId != _modeSequence) {
      return FreshEntryResult.superseded;
    }
    _repairMode = false;
    _operations.currentOperation = null;
    _operations.session = null;
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

  // MARK: - Identifier

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
    _operations.currentOperation = operation;
    _operations.session = null;
    state = state.copyWith(
      identifier: trimmed,
      inFlight: true,
      errorMessage: () => null,
      cancelled: false,
    );
    final settlement = _submitAfterIdentifier(trimmed, operation);
    _operations.pendingSettlements.add(settlement);
    try {
      await settlement;
    } finally {
      _operations.pendingSettlements.remove(settlement);
    }
  }

  // MARK: - OTP

  @override
  void submitOtp(String otp) {
    final pending = _operations.otpCompleter;
    if (pending == null || pending.isCompleted) return;
    final trimmed = otp.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        errorMessage: () => 'Enter the six-digit code sent to your email.',
      );
      return;
    }
    state = state.copyWith(errorMessage: () => null, otpWaiting: false);
    _operations.otpCompleter = null;
    final acceptedOperation = _operations.currentOperation;
    if (_repairMode && acceptedOperation != null) {
      acceptedOperation.otpAccepted = true;
      emitStep(ShowProgressResume());
    }
    pending.complete(trimmed);
  }

  @override
  void cancelOtp() {
    final pending = _operations.otpCompleter;
    if (pending == null || pending.isCompleted) return;
    _operations.otpCompleter = null;
    state = state.copyWith(otpWaiting: false);
    pending.completeError(const SyncEnrollmentOtpCancelled());
  }

  @override
  Future<void> requestNewCode() async {
    // Only one OTP resolver waiting means repeated taps cannot stack sessions.
    final waiting = _operations.otpCompleter;
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

  // MARK: - Dismissal

  @override
  void dismissRepairFlow() => emitStep(DismissRepairFlow());

  @override
  void dismissFlow() => emitStep(DismissEnrollmentFlow());

  // MARK: - Cancellation

  @override
  void cancelPendingOperation() {
    final operation = _operations.currentOperation;
    final cancelsAcceptedOtp =
        operation != null && operation.otpAccepted && state.inFlight;
    operation?.cancel();
    _operations.currentOperation = null;
    // A disposed route no longer owns its pending fresh entry; a newer mode
    // entry already superseded it or will claim the next id.
    _modeSequence++;
    final pending = _operations.otpCompleter;
    _operations.otpCompleter = null;
    _operations.session = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const SyncEnrollmentOtpCancelled());
    }
    // The Flow calls this while the tree finalizes, so provider writes must be
    // deferred.
    if (ref.mounted) {
      scheduleMicrotask(() {
        if (!ref.mounted || _operations.currentOperation != null) return;
        if (cancelsAcceptedOtp && _repairMode) {
          emitStep(ShowOtpEntry());
        }
        state = state.copyWith(inFlight: false, otpWaiting: false);
      });
    }
  }

  // MARK: - Retry

  @override
  Future<void> retry() async {
    if (state.inFlight) return;
    final operation = _EnrollmentOperation();
    _operations.currentOperation = operation;
    state = state.copyWith(
      inFlight: true,
      errorMessage: () => null,
      cancelled: false,
    );
    final settlement = _retryAfterStart(operation);
    _operations.pendingSettlements.add(settlement);
    try {
      await settlement;
    } finally {
      _operations.pendingSettlements.remove(settlement);
    }
  }

  // MARK: - Enrollment Helpers

  Future<bool?> enterRepairMode() {
    final settlement = _enterRepairMode();
    final tracked = settlement.then<void>((_) {}, onError: (_) {});
    _operations.pendingSettlements.add(tracked);
    return settlement.whenComplete(
      () => _operations.pendingSettlements.remove(tracked),
    );
  }

  Future<bool?> _enterRepairMode() async {
    _modeSequence++;
    if (state.inFlight) return state.repairPhase != null;
    _repairMode = true;
    final operation = _EnrollmentOperation();
    _operations.currentOperation = operation;
    _operations.session = null;
    return _finishEnteringRepairMode(
      operation: operation,
      operations: _operations,
      updateState: updateState,
      isMounted: () => ref.mounted,
      currentPhase: _currentPhase,
      emitStep: emitStep,
    );
  }

  bool get _priorOperationPending =>
      _priorEnrollmentOperationPending(state, _operations);

  Future<void> _settlePriorOperation() => _settlePriorEnrollmentOperation(
    readState: () => state,
    operations: _operations,
  );

  Future<void> _submitAfterIdentifier(
    String identifier,
    _EnrollmentOperation operation,
  ) => _submitEnrollmentAfterIdentifier(
    identifier: identifier,
    operation: operation,
    operations: _operations,
    isMounted: () => ref.mounted,
    updateState: updateState,
    enrollFromIdentifier: _enrollFromIdentifier,
    refreshSyncStatus: _refreshSyncStatus,
  );

  Future<void> _enrollFromIdentifier(
    String identifier,
    _EnrollmentOperation operation,
  ) => _enrollWithIdentifier(
    identifier: identifier,
    operation: operation,
    operations: _operations,
    isMounted: () => ref.mounted,
    repairMode: () => _repairMode,
    updateState: updateState,
    emitStep: emitStep,
    noteCodeRequested: _noteCodeRequested,
    openSession: _openSession,
    refreshRepairPhase: _refreshRepairPhase,
    enterCancelled: _enterCancelled,
    failPhaseAware: _failPhaseAware,
    publishAbandonedRepairProof: _publishAbandonedRepairProof,
    completeRepairIfProofPresent: _completeRepairIfProofPresent,
    publishUntilPublished: _publishUntilPublished,
  );

  Future<SyncEnrollmentSessionResult?> _openSession({
    required String identifier,
    required Future<String> Function(EnrollmentChallenge challenge) resolveOtp,
    required _EnrollmentOperation operation,
  }) => _openEnrollmentSession(
    identifier: identifier,
    resolveOtp: resolveOtp,
    operation: operation,
    opener: _opener,
    failPhaseAware: _failPhaseAware,
  );

  Future<void> _retryAfterStart(_EnrollmentOperation operation) =>
      _retryEnrollmentAfterStart(
        operation: operation,
        operations: _operations,
        isMounted: () => ref.mounted,
        repairMode: () => _repairMode,
        updateState: updateState,
        emitStep: emitStep,
        currentPhase: _currentPhase,
        resumeWithoutCredentials: _resumeWithoutCredentials,
        refreshSyncStatus: _refreshSyncStatus,
      );

  Future<void> _resumeWithoutCredentials(_EnrollmentOperation operation) =>
      _resumeEnrollmentWithoutCredentials(
        operation: operation,
        operations: _operations,
        isMounted: () => ref.mounted,
        repairMode: () => _repairMode,
        reopenForResume: _reopenForResume,
        failPhaseAware: _failPhaseAware,
        completeRepairIfProofPresent: _completeRepairIfProofPresent,
        publishUntilPublished: _publishUntilPublished,
      );

  Future<SyncEnrollmentSession?> _reopenForResume(
    _EnrollmentOperation operation,
  ) => _reopenEnrollmentForResume(
    identifier: state.identifier,
    operation: operation,
    operations: _operations,
    isMounted: () => ref.mounted,
    updateState: updateState,
    openSession: _openSession,
  );

  Future<void> _completeRepairIfProofPresent(
    SyncEnrollmentSession session,
    _EnrollmentOperation operation,
  ) => _completeEnrollmentRepairIfProofPresent(
    session: session,
    operation: operation,
    operations: _operations,
    secretStore: _secretStore,
    isMounted: () => ref.mounted,
    updateState: updateState,
    emitStep: emitStep,
    failPhaseAware: _failPhaseAware,
    publishUntilPublished: _publishUntilPublished,
  );

  Future<void> _publishUntilPublished(
    SyncEnrollmentSession session,
    _EnrollmentOperation operation,
  ) => _publishEnrollmentUntilPublished(
    session: session,
    operation: operation,
    operations: _operations,
    isMounted: () => ref.mounted,
    updateState: updateState,
    emitStep: emitStep,
    failPhaseAware: _failPhaseAware,
  );

  Future<void> _publishAbandonedRepairProof(SyncEnrollmentSession session) =>
      _publishAbandonedEnrollmentRepairProof(
        session: session,
        operations: _operations,
        runAbandonedPublication: _runAbandonedPublication,
      );

  Future<void> _runAbandonedPublication(SyncEnrollmentSession session) =>
      _runAbandonedEnrollmentPublication(
        session: session,
        secretStore: _secretStore,
        isMounted: () => ref.mounted,
        refreshSyncStatus: _refreshSyncStatus,
      );

  void _enterCancelled(_EnrollmentOperation operation) =>
      _enterEnrollmentCancelled(
        operation: operation,
        operations: _operations,
        updateState: updateState,
        emitStep: emitStep,
      );

  Future<void> _failPhaseAware(Object error, _EnrollmentOperation operation) =>
      _failEnrollmentPhaseAware(
        error: error,
        operation: operation,
        operations: _operations,
        isMounted: () => ref.mounted,
        repairMode: () => _repairMode,
        updateState: updateState,
        emitStep: emitStep,
        currentPhase: _currentPhase,
        extendCooldownFrom: _extendCooldownFrom,
      );

  Future<void> _refreshRepairPhase(_EnrollmentOperation operation) =>
      _refreshEnrollmentRepairPhase(
        operation: operation,
        operations: _operations,
        isMounted: () => ref.mounted,
        updateState: updateState,
        currentPhase: _currentPhase,
      );

  Future<void> _refreshSyncStatus() async {
    try {
      await _refreshEnrollmentSyncStatus(ref.read(appBootProvider));
    } catch (_) {}
  }

  Future<SyncEnrollmentPhase> _currentPhase() async =>
      _currentEnrollmentPhase(ref.read(syncMetadataStoreProvider));

  Duration? _codeCooldownRemaining() =>
      _enrollmentCodeCooldownRemaining(state, _now);

  void _noteCodeRequested() => _noteEnrollmentCodeRequested(
    isMounted: () => ref.mounted,
    now: _now,
    updateState: updateState,
  );

  void _extendCooldownFrom(Object error, _EnrollmentOperation operation) =>
      _extendEnrollmentCooldownFrom(
        error: error,
        operation: operation,
        operations: _operations,
        readState: () => state,
        now: _now,
        updateState: updateState,
      );
}

// MARK: - Provider

final syncEnrollmentViewModelProvider =
    NotifierProvider<SyncEnrollmentNotifier, SyncEnrollmentState>(
      SyncEnrollmentNotifier.new,
    );
