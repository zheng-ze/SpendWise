part of '../sync_coordinator.dart';

// MARK: - Coordinator Pull

extension SyncCoordinatorPull on SyncCoordinator {
  static bool _isDuplicateOrDominated(
    RowVersion? stored,
    VersionVector pulled,
  ) => stored != null && stored.versionVector.dominates(pulled);

  Future<void> processPullPage(SyncCollection collection) =>
      _lock.withLock(collection, () => _processPullPageLocked(collection));

  Future<void> _processPullPageLocked(SyncCollection collection) async {
    final _PulledPage page = await _pullAndValidatePage(collection);

    try {
      final ReconcileResult remoteResult = await engine.reconcile(
        page.envelopes,
      );
      final _RemoteProvenance provenance = _indexRemoteProvenance(
        page.envelopes,
        remoteResult,
      );

      var applied = false;
      var everyAttemptWasEmptyAttemptRows = false;

      for (
        var attempt = 1;
        attempt <= SyncCoordinator._maxFoldInAttempts;
        attempt += 1
      ) {
        final _AttemptOutcome outcome = await _runFoldInAttempt(
          collection: collection,
          lease: page.lease,
          nextCursor: page.nextCursor,
          remoteResult: remoteResult,
          remoteWinner: provenance.remoteWinner,
          remoteWinnerChange: provenance.remoteWinnerChange,
        );
        if (outcome is _AttemptRetry) {
          continue;
        }
        if (outcome is _AttemptEmpty) {
          everyAttemptWasEmptyAttemptRows = true;
          break;
        }
        applied = true;
        return;
      }

      if (!applied) {
        if (everyAttemptWasEmptyAttemptRows) {
          await _finalizeAndMaybeAcknowledge(
            collection,
            lease: page.lease,
            stamps: const <SyncRowID, VersionVector>{},
            watermark: page.nextCursor,
            checkpoint: page.nextCursor,
          );
        }
      }
    } on PersistenceBarrierFailure {
      return;
    } finally {
      await stagingStore.flush();
    }
  }

  // MARK: - Pull Validation

  Future<_PulledPage> _pullAndValidatePage(SyncCollection collection) async {
    final SyncBackend? backend = this.backend;
    if (backend == null) {
      throw StateError(
        'Cannot pull $collection before enrollment: no sync backend.',
      );
    }
    final SyncMetadataSnapshot snapshot = await metadataStore.snapshot();
    final String? cursor = snapshot.watermarks[collection];
    final _BoundRpcResult<PullResponse> result =
        await _sendBoundRpc<PullResponse>(
          operation: 'pull $collection',
          call: (BoundDeviceCredential credential) => backend.pull(
            credential,
            PullRequest(collection: collection, cursor: cursor),
          ),
        );
    final PullResponse response;
    switch (result.outcome) {
      case SyncSuccess<PullResponse>(value: final value):
        response = value;
      case SyncFailure<PullResponse>(code: final code, message: final message):
        throw StateError('Pull of $collection failed ($code): $message.');
    }
    final List<SyncEnvelope> envelopes = response.envelopes;
    for (final SyncEnvelope envelope in envelopes) {
      if (envelope.collection != collection) {
        throw StateError(
          'Pull of $collection returned an envelope for '
          '${envelope.collection}.',
        );
      }
    }
    return _PulledPage(
      envelopes: envelopes,
      nextCursor: response.cursor,
      lease: result.lease,
    );
  }

  _RemoteProvenance _indexRemoteProvenance(
    List<SyncEnvelope> envelopes,
    ReconcileResult remoteResult,
  ) {
    final Map<SyncRowID, SyncEnvelope> remoteWinner =
        <SyncRowID, SyncEnvelope>{};
    for (final MapEntry<SyncRowID, int> entry
        in remoteResult.winningInputIndex.entries) {
      final int index = entry.value;
      if (index < 0 || index >= envelopes.length) continue;
      remoteWinner[entry.key] = envelopes[index];
    }
    final Map<SyncRowID, LedgerChange> remoteWinnerChange =
        <SyncRowID, LedgerChange>{};
    for (final LedgerChange change in remoteResult.changes) {
      remoteWinnerChange[SyncRowID.of(collectionFor(change), change.targetID)] =
          change;
    }
    return _RemoteProvenance(
      remoteWinner: remoteWinner,
      remoteWinnerChange: remoteWinnerChange,
    );
  }

  // MARK: - Fold-In Attempt

  Future<_AttemptOutcome> _runFoldInAttempt({
    required SyncCollection collection,
    required BoundRpcLease lease,
    required String nextCursor,
    required ReconcileResult remoteResult,
    required Map<SyncRowID, SyncEnvelope> remoteWinner,
    required Map<SyncRowID, LedgerChange> remoteWinnerChange,
  }) async {
    final MutationFence fence = MutationFence(ledger.bus)..install();
    try {
      final int epoch = fence.snapshot();

      await versionSource.refresh();
      final _AttemptClassification classification = _classifyAttemptRows(
        remoteResult.stamps,
      );
      if (classification.attemptRows.isEmpty) {
        return const _AttemptEmpty();
      }

      await persistenceProcessor.flush();
      await versionSource.refresh();
      if (!fence.checkClean(epoch)) {
        return const _AttemptRetry();
      }

      final _AttemptSnapshot captured = _captureAttemptSnapshot(
        classification.attemptRows,
      );

      final _FoldInOutcome foldIn = await _reconcileFoldInCandidates(
        foldInCandidates: classification.foldInCandidates,
        remoteWinner: remoteWinner,
        refreshedContent: captured.refreshedContent,
      );
      if (foldIn.excluded) {
        return const _AttemptRetry();
      }

      final _FinalDecision decision = _finalizeSynchronously(
        directApplyCandidates: classification.directApplyCandidates,
        remoteEligible: foldIn.remoteEligible,
        remoteWinnerChange: remoteWinnerChange,
        remoteStamps: remoteResult.stamps,
        refreshedVersions: captured.refreshedVersions,
        fence: fence,
        epoch: epoch,
      );
      if (decision.raceDetected) {
        return const _AttemptRetry();
      }

      if (decision.changes.isNotEmpty) {
        ledger.applySyncBatch(decision.changes, decision.stamps);
      }

      if (decision.changes.isNotEmpty) {
        await persistenceProcessor.flush();
        final Map<SyncRowID, RowReadbackOutcome> outcomes = await verifier
            .verify(decision.stamps);
        if (outcomes.values.any((result) => !result.passed)) {
          return const _AttemptDone();
        }
      }

      await _finalizeAndMaybeAcknowledge(
        collection,
        lease: lease,
        stamps: decision.stamps,
        watermark: nextCursor,
        checkpoint: nextCursor,
      );
      return const _AttemptDone();
    } finally {
      await fence.uninstall();
    }
  }

  _AttemptClassification _classifyAttemptRows(
    Map<SyncRowID, VersionVector> stamps,
  ) {
    final Set<SyncRowID> directApplyCandidates = <SyncRowID>{};
    final Set<SyncRowID> foldInCandidates = <SyncRowID>{};
    for (final MapEntry<SyncRowID, VersionVector> entry in stamps.entries) {
      final SyncRowID row = entry.key;
      final RowVersion? stored = versionSource.readRowVersion(row);
      if (_isDuplicateOrDominated(stored, entry.value)) continue;
      if (stored == null) {
        directApplyCandidates.add(row);
      } else {
        foldInCandidates.add(row);
      }
    }
    final Set<SyncRowID> attemptRows = <SyncRowID>{
      ...directApplyCandidates,
      ...foldInCandidates,
    };
    return _AttemptClassification(
      directApplyCandidates: directApplyCandidates,
      foldInCandidates: foldInCandidates,
      attemptRows: attemptRows,
    );
  }

  _AttemptSnapshot _captureAttemptSnapshot(Set<SyncRowID> attemptRows) {
    final Map<SyncRowID, RowVersion?> refreshedVersions =
        <SyncRowID, RowVersion?>{};
    for (final SyncRowID row in attemptRows) {
      refreshedVersions[row] = versionSource.readRowVersion(row);
    }
    final LedgerState liveState = ledger.state;
    final Map<SyncRowID, LedgerChange> refreshedContent =
        <SyncRowID, LedgerChange>{};
    for (final SyncRowID row in attemptRows) {
      refreshedContent[row] = _currentLocalChange(liveState, row);
    }
    return _AttemptSnapshot(
      refreshedVersions: refreshedVersions,
      refreshedContent: refreshedContent,
    );
  }

  // MARK: - Fold-In Reconciliation

  Future<_FoldInOutcome> _reconcileFoldInCandidates({
    required Set<SyncRowID> foldInCandidates,
    required Map<SyncRowID, SyncEnvelope> remoteWinner,
    required Map<SyncRowID, LedgerChange> refreshedContent,
  }) async {
    var foldInExcluded = false;
    final Map<SyncRowID, VersionVector> remoteEligible =
        <SyncRowID, VersionVector>{};
    for (final SyncRowID row in foldInCandidates) {
      final SyncEnvelope? remote = remoteWinner[row];
      final LedgerChange? local = refreshedContent[row];
      if (remote == null || local == null) {
        foldInExcluded = true;
        continue;
      }
      final List<SyncEnvelope> encoded = await engine.encode(<LedgerChange>[
        local,
      ], versionSource);
      if (encoded.length != 1) {
        foldInExcluded = true;
        continue;
      }
      final ReconcileResult foldInResult = await engine.reconcile(
        <SyncEnvelope>[remote, encoded[0]],
      );
      final int? winner = foldInResult.winningInputIndex[row];
      switch (winner) {
        case 0:
          final VersionVector? stamp = foldInResult.stamps[row];
          if (stamp == null) {
            foldInExcluded = true;
          } else {
            remoteEligible[row] = stamp;
          }
        case 1:
          break;
        case null:
          break;
      }
    }
    return _FoldInOutcome(
      excluded: foldInExcluded,
      remoteEligible: remoteEligible,
    );
  }

  // MARK: - Synchronous Finalize

  _FinalDecision _finalizeSynchronously({
    required Set<SyncRowID> directApplyCandidates,
    required Map<SyncRowID, VersionVector> remoteEligible,
    required Map<SyncRowID, LedgerChange> remoteWinnerChange,
    required Map<SyncRowID, VersionVector> remoteStamps,
    required Map<SyncRowID, RowVersion?> refreshedVersions,
    required MutationFence fence,
    required int epoch,
  }) {
    final List<LedgerChange> changes = <LedgerChange>[];
    final Map<SyncRowID, VersionVector> stamps = <SyncRowID, VersionVector>{};
    for (final SyncRowID row in directApplyCandidates) {
      if (versionSource.readRowVersion(row) != null) {
        return const _FinalDecision.raceDetected();
      }
      final LedgerChange? change = remoteWinnerChange[row];
      final VersionVector? stamp = remoteStamps[row];
      if (change == null || stamp == null) {
        return const _FinalDecision.raceDetected();
      }
      changes.add(change);
      stamps[row] = stamp;
    }
    for (final MapEntry<SyncRowID, VersionVector> entry
        in remoteEligible.entries) {
      final SyncRowID row = entry.key;
      final RowVersion? reconciledAgainst = refreshedVersions[row];
      final RowVersion? current = versionSource.readRowVersion(row);
      if (reconciledAgainst == null ||
          current == null ||
          reconciledAgainst.versionVector != current.versionVector) {
        return const _FinalDecision.raceDetected();
      }
      final LedgerChange? change = remoteWinnerChange[row];
      if (change == null) {
        return const _FinalDecision.raceDetected();
      }
      changes.add(change);
      stamps[row] = entry.value;
    }
    if (!fence.checkClean(epoch)) {
      return const _FinalDecision.raceDetected();
    }
    if (changes.isEmpty) {
      return const _FinalDecision.raceDetected();
    }
    return _FinalDecision.commit(changes: changes, stamps: stamps);
  }

  Future<void> _finalizeAndMaybeAcknowledge(
    SyncCollection collection, {
    required BoundRpcLease lease,
    required Map<SyncRowID, VersionVector> stamps,
    required String watermark,
    required String checkpoint,
  }) async {
    await stagingStore.flush();
    await repairGate.withCurrentLease(
      lease,
      () => metadataStore.recordPulledPage(
        collection: collection,
        vectors: stamps,
        watermark: watermark,
        checkpoint: checkpoint,
      ),
    );
  }

  // MARK: - Local Change Mapping

  LedgerChange _currentLocalChange(LedgerState state, SyncRowID row) {
    switch (row.collection) {
      case SyncCollection.moneySources:
        final MoneySource? source = state.moneySources[row.rowID];
        if (source == null || source.lifecycle == LifecycleState.tombstoned) {
          return deleteFor(row.collection, row.rowID);
        }
        return LedgerChange.upsertSource(source);
      case SyncCollection.categories:
        final TransactionCategory? category = state.categories[row.rowID];
        if (category == null ||
            category.lifecycle == LifecycleState.tombstoned) {
          return deleteFor(row.collection, row.rowID);
        }
        return UpsertCategory(category);
      case SyncCollection.entries:
        final Entry? entry =
            state.entries[row.rowID] ?? state.binnedEntries[row.rowID];
        if (entry == null || entry.lifecycle == LifecycleState.tombstoned) {
          return deleteFor(row.collection, row.rowID);
        }
        return UpsertEntry(entry);
      case SyncCollection.plans:
        final RecurringPlan? plan = state.plans[row.rowID];
        if (plan == null) return deleteFor(row.collection, row.rowID);
        return UpsertPlan(plan);
      case SyncCollection.budgets:
        final Budget? budget = state.budgets[row.rowID];
        if (budget == null) return deleteFor(row.collection, row.rowID);
        return UpsertBudget(budget);
    }
  }
}
