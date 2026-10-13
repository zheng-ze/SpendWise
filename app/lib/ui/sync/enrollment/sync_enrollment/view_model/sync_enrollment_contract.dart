part of '../sync_enrollment_view_model.dart';

// MARK: - View Model Contract

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
