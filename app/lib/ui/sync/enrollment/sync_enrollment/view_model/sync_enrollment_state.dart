part of '../sync_enrollment_view_model.dart';

// MARK: - Enrollment State

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
