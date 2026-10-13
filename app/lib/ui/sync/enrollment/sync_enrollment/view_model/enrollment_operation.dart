part of '../sync_enrollment_view_model.dart';

// MARK: - Enrollment Operation

final class _EnrollmentOperation {
  bool cancelled = false;
  bool otpAccepted = false;

  void cancel() => cancelled = true;
}
