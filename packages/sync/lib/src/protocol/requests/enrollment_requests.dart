part of '../../../sync.dart';

// MARK: - Enrollment Requests

final class BeginEnrollmentRequest {
  BeginEnrollmentRequest(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}

final class EnrollmentChallenge {
  EnrollmentChallenge(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}

final class CompleteEnrollmentRequest {
  CompleteEnrollmentRequest(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}
