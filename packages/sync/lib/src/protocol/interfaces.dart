part of '../../sync.dart';

abstract interface class SyncBackend {
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  );

  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  );

  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  );

  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  );
}

abstract interface class SyncAuthenticator {
  Future<SyncOutcome<EnrollmentChallenge>> beginEnrollment(
    BeginEnrollmentRequest request,
  );

  Future<SyncOutcome<DeviceCredential>> completeEnrollment(
    CompleteEnrollmentRequest request,
  );

  Future<SyncOutcome<DeviceCredential>> refreshCredential(
    DeviceCredential credential,
  );
}

abstract interface class DeviceBindingAuthorizer {
  Future<SyncOutcome<StartDeviceBindingResponse>> startBinding(
    StartDeviceBindingRequest request,
  );

  Future<SyncOutcome<VerifyDeviceBindingResponse>> verifyBinding(
    VerifyDeviceBindingRequest request,
  );
}
