part of '../../sync.dart';

/// Narrow scoped accessor the engine uses to obtain the raw E2E key.
///
/// The engine never receives the app's general SecretStore or the opaque
/// credential payload; this is its only key-related dependency.
typedef SyncE2EKeyAccessor = Future<Uint8List> Function();

/// Output of [SyncEngine.reconcile]: the conflict-free stamped changes, the
/// per-row stamps, and the staged conflict groups.
@immutable
final class ReconcileResult {
  const ReconcileResult({
    required this.changes,
    required this.stamps,
    required this.stagedConflicts,
  });

  final List<LedgerChange> changes;
  final Map<SyncRowID, VersionVector> stamps;
  final List<StagedConflict> stagedConflicts;

  bool get hasConflicts => stagedConflicts.isNotEmpty;
}

/// Flutter-free sync engine: encodes local rows, decrypts and decodes pulled
/// envelopes, groups mutually concurrent siblings by [SyncRowID], and either
/// returns stamped conflict-free [LedgerChange]s or stages conflicting groups.
class SyncEngine {
  SyncEngine({
    required this.userID,
    required SyncE2EKeyAccessor keyAccessor,
    SyncStagingStore? stagingStore,
  })  : _keyAccessor = keyAccessor,
        _staging = stagingStore ?? InMemorySyncStagingStore();

  /// Device/user identity placed in every pushed envelope.
  final String userID;

  final SyncE2EKeyAccessor _keyAccessor;
  final SyncStagingStore _staging;
  final PayloadCodec _codec = const PayloadCodec();
  final SyncCipher _cipher = const SyncCipher();

  /// Decrypts, decodes, groups, and classifies [envelopes].
  ///
  /// Throws [SyncPayloadDecryptionError] on AEAD authentication failure.
  Future<ReconcileResult> reconcile(Iterable<SyncEnvelope> envelopes) async {
    final key = await _keyAccessor();
    final decoded = <_DecodedRow>[];
    for (final envelope in envelopes) {
      final rowID = SyncRowID.of(envelope.collection, envelope.rowID);
      final change = await _decodeRow(key, envelope);
      decoded.add(_DecodedRow(rowID, change, envelope));
    }

    final byRow = <SyncRowID, List<_DecodedRow>>{};
    for (final row in decoded) {
      (byRow[row.rowID] ??= <_DecodedRow>[]).add(row);
    }

    final changes = <LedgerChange>[];
    final stamps = <SyncRowID, VersionVector>{};
    final stagedConflicts = <StagedConflict>[];

    for (final rowID in byRow.keys) {
      final siblings = byRow[rowID]!;
      if (_hasConcurrentSiblings(siblings)) {
        final group = StagedConflict(
          siblings.first.envelope.collection,
          siblings.first.envelope.rowID,
          siblings.map((sibling) => sibling.envelope).toList(),
        );
        stagedConflicts.add(group);
        _staging.stage(group);
        continue;
      }
      final winner = _winnerOf(siblings);
      changes.add(winner.change);
      stamps[rowID] = winner.envelope.versionVector;
    }

    return ReconcileResult(
      changes: changes,
      stamps: stamps,
      stagedConflicts: stagedConflicts,
    );
  }

  Future<LedgerChange> _decodeRow(
    Uint8List key,
    SyncEnvelope envelope,
  ) async {
    if (envelope.lifecycle == SiblingLifecycle.tombstone) {
      return deleteFor(envelope.collection, envelope.rowID);
    }
    final aad = envelope.aadBytes();
    final plaintext = await _cipher.decrypt(
      key: key,
      ciphertext: envelope.ciphertext,
      aad: aad,
    );
    return _codec.decodeChange(plaintext);
  }

  static bool _hasConcurrentSiblings(List<_DecodedRow> siblings) {
    for (var i = 0; i < siblings.length; i += 1) {
      for (var j = i + 1; j < siblings.length; j += 1) {
        if (siblings[i]
            .envelope
            .versionVector
            .isConcurrent(siblings[j].envelope.versionVector)) {
          return true;
        }
      }
    }
    return false;
  }

  static _DecodedRow _winnerOf(List<_DecodedRow> siblings) {
    for (final candidate in siblings) {
      final dominatesAll = siblings.every(
        (sibling) => candidate.envelope.versionVector
            .dominates(sibling.envelope.versionVector),
      );
      if (dominatesAll) return candidate;
    }
    throw StateError('No dominant sibling in a concurrent-free group.');
  }

  /// Converts local [changes] plus their exact stored versions into
  /// push-ready envelopes.
  Future<List<SyncEnvelope>> encode(
    Iterable<LedgerChange> changes,
    SyncVersionSource versionSource,
  ) async {
    final key = await _keyAccessor();
    final envelopes = <SyncEnvelope>[];
    for (final change in changes) {
      final collection = collectionFor(change);
      final rowID = normalizedID(change.targetID);
      final row = SyncRowID.of(collection, rowID);
      final stored = versionSource.readRowVersion(row);
      final version = stored?.versionVector ?? VersionVector.empty;
      final lifecycle = _lifecycleFor(change);
      final payload = Uint8List.fromList(_codec.encodeChange(change));
      final ciphertext = await _framePayload(
        key: key,
        payload: payload,
        collection: collection,
        rowID: rowID,
        versionVector: version,
        lifecycle: lifecycle,
      );
      envelopes.add(SyncEnvelope(
        protocolVersion: syncProtocolVersion,
        userID: userID,
        collection: collection,
        rowID: rowID,
        siblingID: computeSiblingID(
          userID: userID,
          collection: collection,
          rowID: rowID,
          versionVector: version,
        ),
        versionVector: version,
        lifecycle: lifecycle,
        ciphertext: ciphertext,
      ));
    }
    return envelopes;
  }

  /// Frames [payload] with a fresh nonce under [key], binding every visible
  /// envelope field except ciphertext via AAD.
  Future<String> _framePayload({
    required Uint8List key,
    required Uint8List payload,
    required SyncCollection collection,
    required String rowID,
    required VersionVector versionVector,
    required SiblingLifecycle lifecycle,
  }) async {
    final preview = SyncEnvelope(
      protocolVersion: syncProtocolVersion,
      userID: userID,
      collection: collection,
      rowID: rowID,
      siblingID: computeSiblingID(
        userID: userID,
        collection: collection,
        rowID: rowID,
        versionVector: versionVector,
      ),
      versionVector: versionVector,
      lifecycle: lifecycle,
      ciphertext: '',
    );
    final framed = await _cipher.encrypt(
      key: key,
      plaintext: payload,
      aad: preview.aadBytes(),
    );
    return base64Url.encode(framed).replaceAll('=', '');
  }

  static SiblingLifecycle _lifecycleFor(LedgerChange change) =>
      change is DeleteBudget ||
              change is DeleteCategory ||
              change is DeleteEntry ||
              change is DeletePlan ||
              change is DeleteMoneySource
          ? SiblingLifecycle.tombstone
          : SiblingLifecycle.live;
}

/// Maps a [LedgerChange] to its [SyncCollection]. Total across every variant.
SyncCollection collectionFor(LedgerChange change) {
  switch (change) {
    case UpsertAccount() || UpsertPocket() || DeleteMoneySource():
      return SyncCollection.moneySources;
    case UpsertCategory() || DeleteCategory():
      return SyncCollection.categories;
    case UpsertEntry() || DeleteEntry():
      return SyncCollection.entries;
    case UpsertPlan() || DeletePlan():
      return SyncCollection.plans;
    case UpsertBudget() || DeleteBudget():
      return SyncCollection.budgets;
  }
}

/// Builds the payload-free delete change for a tombstone envelope.
LedgerChange deleteFor(SyncCollection collection, String rowID) =>
    switch (collection) {
      SyncCollection.moneySources => DeleteMoneySource(normalizedID(rowID)),
      SyncCollection.categories => DeleteCategory(normalizedID(rowID)),
      SyncCollection.entries => DeleteEntry(normalizedID(rowID)),
      SyncCollection.plans => DeletePlan(normalizedID(rowID)),
      SyncCollection.budgets => DeleteBudget(normalizedID(rowID)),
    };

class _DecodedRow {
  const _DecodedRow(this.rowID, this.change, this.envelope);
  final SyncRowID rowID;
  final LedgerChange change;
  final SyncEnvelope envelope;
}
