part of '../sync_coordinator.dart';

// MARK: - Presented Bound Credential

final class _PresentedBound {
  const _PresentedBound({required this.credential, required this.deviceSecret});

  final BoundDeviceCredential credential;
  final String deviceSecret;
}

// MARK: - Bound RPC Result

final class _BoundRpcResult<T> {
  const _BoundRpcResult(this.outcome, this.lease);

  final SyncOutcome<T> outcome;
  final BoundRpcLease lease;
}

// MARK: - Submitted Push

final class _SubmittedPush {
  const _SubmittedPush({required this.vector, required this.siblingID});

  final VersionVector vector;
  final String siblingID;
}

// MARK: - Pulled Page

final class _PulledPage {
  const _PulledPage({
    required this.envelopes,
    required this.nextCursor,
    required this.lease,
  });

  final List<SyncEnvelope> envelopes;
  final String nextCursor;
  final BoundRpcLease lease;
}

// MARK: - Remote Provenance

final class _RemoteProvenance {
  const _RemoteProvenance({
    required this.remoteWinner,
    required this.remoteWinnerChange,
  });

  final Map<SyncRowID, SyncEnvelope> remoteWinner;
  final Map<SyncRowID, LedgerChange> remoteWinnerChange;
}

// MARK: - Fold-In Attempt State

final class _AttemptClassification {
  const _AttemptClassification({
    required this.directApplyCandidates,
    required this.foldInCandidates,
    required this.attemptRows,
  });

  final Set<SyncRowID> directApplyCandidates;
  final Set<SyncRowID> foldInCandidates;
  final Set<SyncRowID> attemptRows;
}

final class _AttemptSnapshot {
  const _AttemptSnapshot({
    required this.refreshedVersions,
    required this.refreshedContent,
  });

  final Map<SyncRowID, RowVersion?> refreshedVersions;
  final Map<SyncRowID, LedgerChange> refreshedContent;
}

final class _FoldInOutcome {
  const _FoldInOutcome({required this.excluded, required this.remoteEligible});

  final bool excluded;
  final Map<SyncRowID, VersionVector> remoteEligible;
}

sealed class _AttemptOutcome {
  const _AttemptOutcome();
}

final class _AttemptRetry extends _AttemptOutcome {
  const _AttemptRetry();
}

final class _AttemptEmpty extends _AttemptOutcome {
  const _AttemptEmpty();
}

final class _AttemptDone extends _AttemptOutcome {
  const _AttemptDone();
}

final class _FinalDecision {
  const _FinalDecision.raceDetected()
    : changes = const <LedgerChange>[],
      stamps = const <SyncRowID, VersionVector>{},
      raceDetected = true;

  _FinalDecision.commit({
    required List<LedgerChange> changes,
    required Map<SyncRowID, VersionVector> stamps,
  }) : changes = List.unmodifiable(changes),
       stamps = Map.unmodifiable(stamps),
       raceDetected = false;

  final List<LedgerChange> changes;
  final Map<SyncRowID, VersionVector> stamps;
  final bool raceDetected;
}
