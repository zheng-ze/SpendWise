// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of '../sync_enrollment_view_model.dart';

// MARK: - Snapshot Publication

extension SyncEnrollmentPublication on SyncEnrollmentNotifier {
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
        if (attempts >= SyncEnrollmentNotifier.maxPublishAttempts) {
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
        await Future<void>.delayed(SyncEnrollmentNotifier._publishRetryDelay);
        if (!ref.mounted || !identical(operation, _currentOperation)) return;
      }
    } on Object catch (error) {
      await _failPhaseAware(error, operation);
    }
  }

  // MARK: - Abandoned Publication

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
        for (
          var attempt = 1;
          attempt <= SyncEnrollmentNotifier.maxPublishAttempts;
          attempt++
        ) {
          final outcome = await session.publishSnapshot();
          if (outcome is EnrollmentSnapshotPublished) break;
          if (attempt == SyncEnrollmentNotifier.maxPublishAttempts) break;
          await Future<void>.delayed(SyncEnrollmentNotifier._publishRetryDelay);
        }
      }
    } on Object catch (_) {}
    if (ref.mounted) await _refreshSyncStatus();
  }
}
