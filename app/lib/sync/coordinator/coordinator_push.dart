part of '../sync_coordinator.dart';

// MARK: - Coordinator Push

extension SyncCoordinatorPush on SyncCoordinator {
  Future<void> recoverPendingAcknowledgements() async {
    final SyncBackend? backend = this.backend;
    if (backend == null) {
      throw StateError(
        'Cannot acknowledge before enrollment: no sync backend.',
      );
    }
    final Map<SyncCollection, String> pending = await metadataStore
        .pendingAcknowledgements();
    for (final MapEntry<SyncCollection, String> entry in pending.entries) {
      await _lock.withLock(
        entry.key,
        () => _recoverOneAcknowledgement(backend, entry.key, entry.value),
      );
    }
  }

  Future<void> _recoverOneAcknowledgement(
    SyncBackend backend,
    SyncCollection collection,
    String checkpoint,
  ) => _recoverOneAcknowledgementLocked(backend, collection, checkpoint);

  Future<void> _recoverOneAcknowledgementLocked(
    SyncBackend backend,
    SyncCollection collection,
    String checkpoint,
  ) async {
    final List<StagedConflict> staged = await stagingStore
        .pendingConflictList();
    if (staged.any(
      (StagedConflict conflict) => conflict.collection == collection,
    )) {
      return;
    }
    final _BoundRpcResult<AcknowledgeResponse> result =
        await _sendBoundRpc<AcknowledgeResponse>(
          operation: 'acknowledge $collection',
          call: (BoundDeviceCredential credential) => backend.acknowledge(
            credential,
            AcknowledgeRequest(collection: collection, checkpoint: checkpoint),
          ),
        );
    switch (result.outcome) {
      case SyncSuccess<AcknowledgeResponse>():
        await repairGate.withCurrentLease(
          result.lease,
          () => metadataStore.clearPendingAcknowledgementIfMatches(
            collection,
            checkpoint,
          ),
        );
      case SyncFailure<AcknowledgeResponse>():
        break;
    }
  }

  // MARK: - Push Collection

  Future<PushCollectionResult> pushCollection(
    SyncCollection collection, {
    String? writeProof,
  }) => _lock.withLock(
    collection,
    () => _pushCollectionLocked(collection, writeProof: writeProof),
  );

  Future<PushCollectionResult> _pushCollectionLocked(
    SyncCollection collection, {
    String? writeProof,
  }) async {
    final SyncMetadataSnapshot gate = await metadataStore.snapshot();
    final HostedOperationLegality legality = metadataStore
        .validateHostedOperationState(gate);
    if (legality is HostedOperationIllegal) {
      throw StateError('Cannot push $collection: ${legality.reason}');
    }
    if (!gate.writeEnabled) {
      throw StateError(
        'Cannot push $collection while sync writes are disabled.',
      );
    }
    final SyncBackend? backend = this.backend;
    if (backend == null) {
      throw StateError(
        'Cannot push $collection before enrollment: no sync backend.',
      );
    }

    final String? pending = await metadataStore.pendingAcknowledgement(
      collection,
    );
    if (pending != null) {
      await _recoverOneAcknowledgementLocked(backend, collection, pending);
      if (await metadataStore.pendingAcknowledgement(collection) != null) {
        return const PushDeferred();
      }
    }

    await persistenceProcessor.flush();
    await versionSource.refresh();

    final Map<SyncRowID, RowVersion> stored = await versionReader
        .readRowVersions(collection);
    final Map<SyncRowID, VersionVector> acknowledged = await metadataStore
        .acknowledgedVectors();
    final List<SyncRowID> candidates = <SyncRowID>[];
    for (final MapEntry<SyncRowID, RowVersion> entry in stored.entries) {
      final VersionVector? acked = acknowledged[entry.key];
      if (acked == null || !acked.dominates(entry.value.versionVector)) {
        candidates.add(entry.key);
      }
    }
    if (candidates.isEmpty) {
      return const PushNoop();
    }

    final LedgerState liveState = ledger.state;
    final List<LedgerChange> changes = <LedgerChange>[
      for (final SyncRowID row in candidates)
        _currentLocalChange(liveState, row),
    ];
    final List<SyncEnvelope> envelopes = await engine.encode(
      changes,
      versionSource,
    );
    final Map<SyncRowID, _SubmittedPush> submitted = Map.unmodifiable(
      <SyncRowID, _SubmittedPush>{
        for (final SyncEnvelope envelope in envelopes)
          SyncRowID.of(envelope.collection, envelope.rowID): _SubmittedPush(
            vector: envelope.versionVector,
            siblingID: envelope.siblingID,
          ),
      },
    );

    final _BoundRpcResult<PushResponse> result =
        await _sendBoundRpc<PushResponse>(
          operation: 'push $collection',
          call: (BoundDeviceCredential credential) => backend.push(
            credential,
            PushRequest(envelopes: envelopes, writeProof: writeProof),
          ),
        );
    final PushResponse response;
    switch (result.outcome) {
      case SyncSuccess<PushResponse>(value: final value):
        response = value;
      case SyncFailure<PushResponse>(code: final code, message: final message):
        throw StateError('Push of $collection failed ($code): $message.');
    }
    final Map<SyncRowID, PushRowOutcome> rowOutcomes;
    try {
      rowOutcomes = response.rowOutcomes;
    } on FormatException {
      return PushUnresolvedRows(submitted.keys.toSet());
    }
    final Set<SyncRowID> unresolved = <SyncRowID>{};
    for (final MapEntry<SyncRowID, _SubmittedPush> entry in submitted.entries) {
      final PushRowOutcome? rowOutcome = rowOutcomes[entry.key];
      if (rowOutcome == null || rowOutcome.siblingID != entry.value.siblingID) {
        unresolved.add(entry.key);
        continue;
      }
      switch (rowOutcome) {
        case PushApplied():
        case PushAlreadyPresent():
          await repairGate.withCurrentLease(
            result.lease,
            () => metadataStore.setAcknowledgedVector(
              entry.key,
              entry.value.vector,
            ),
          );
        case PushRejected():
          unresolved.add(entry.key);
          break;
      }
    }
    if (unresolved.isEmpty) {
      return PushFullyAcknowledged(submitted.keys.toSet());
    }
    return PushUnresolvedRows(unresolved);
  }
}
