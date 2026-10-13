part of '../sync_metadata_store.dart';

// MARK: - Metadata Snapshot

final class SyncMetadataSnapshot {
  const SyncMetadataSnapshot({
    required this.backend,
    required this.endpoint,
    required this.phase,
    required this.writeEnabled,
    this.deviceBindingRequired = false,
    this.deviceBindingState = SyncDeviceBindingState.notApplicable,
    this.reauthResumePhase,
    required this.watermarks,
  });

  final SyncBackendKind? backend;

  final String? endpoint;

  final SyncEnrollmentPhase phase;
  final bool writeEnabled;

  // The row needs binding authorization before writes may resume.
  final bool deviceBindingRequired;

  final SyncDeviceBindingState deviceBindingState;

  final SyncEnrollmentPhase? reauthResumePhase;

  final Map<SyncCollection, String?> watermarks;
}
