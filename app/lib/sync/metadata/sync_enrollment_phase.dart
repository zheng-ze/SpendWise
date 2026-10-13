part of '../sync_metadata_store.dart';

// MARK: - Enrollment Phase

enum SyncEnrollmentPhase {
  notEnrolled(0),

  credentialAcquired(1),
  snapshotInProgress(2),

  reconciliationComplete(3),
  gateEnabled(4),

  bindingAuthorizationRequired(5),
  sessionReauthRequired(6);

  const SyncEnrollmentPhase(this.code);

  final int code;

  static SyncEnrollmentPhase fromCode(int code) => values.firstWhere(
    (phase) => phase.code == code,
    orElse: () =>
        throw FormatException('Unknown sync enrollment phase code: $code.'),
  );
}
