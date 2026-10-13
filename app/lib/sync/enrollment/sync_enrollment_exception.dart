part of '../sync_enrollment_service.dart';

// MARK: - Enrollment Exception

final class SyncEnrollmentException implements Exception {
  const SyncEnrollmentException({
    required this.step,
    required this.code,
    this.message,
    this.retryAfter,
  });

  final String step;
  final String code;
  final String? message;
  final Duration? retryAfter;

  @override
  String toString() =>
      'SyncEnrollmentException($step, $code${message != null ? ": $message" : ""})';
}
