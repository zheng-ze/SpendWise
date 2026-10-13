part of '../sync_enrollment_view_model.dart';

// MARK: - OTP Cancelled

final class SyncEnrollmentOtpCancelled implements Exception {
  const SyncEnrollmentOtpCancelled();

  @override
  String toString() => 'SyncEnrollmentOtpCancelled';
}

// MARK: - Enrollment Steps

sealed class SyncEnrollmentStep {}

final class ShowIdentifierEntry extends SyncEnrollmentStep {}

final class ShowOtpEntry extends SyncEnrollmentStep {}

final class ShowProgressResume extends SyncEnrollmentStep {}

final class ShowEnrollmentCompleted extends SyncEnrollmentStep {}

class DismissEnrollmentFlow extends SyncEnrollmentStep {}

final class DismissRepairFlow extends DismissEnrollmentFlow {}

// MARK: - Fresh Entry Result

enum FreshEntryResult { applied, superseded, timedOut }
