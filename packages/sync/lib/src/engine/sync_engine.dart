part of '../../sync.dart';

/// Narrow scoped accessor the engine uses to obtain the raw E2E key.
///
/// The engine never receives the app's general SecretStore or the opaque
/// credential payload; this is its only key-related dependency.
typedef SyncE2EKeyAccessor = Future<Uint8List> Function();

/// Error thrown when an authenticated envelope's decrypted payload does not
/// match the envelope's declared collection, row ID, or tombstone shape.
///
/// Distinct from [SyncPayloadDecryptionError] (AEAD authentication failure)
/// and [PayloadDecodeError] (authentic bytes this codec cannot read): an
/// identity mismatch means the bytes were authentic but the decoded entity
/// does not belong to this envelope.
final class SyncPayloadIdentityError implements Exception {
  const SyncPayloadIdentityError(this.message);

  final String message;

  @override
  String toString() => 'SyncPayloadIdentityError: $message';
}

/// Error thrown when [SyncEngine.encode] is asked to push a row the version
/// source does not track, so no stored [RowVersion] is available.
final class SyncUntrackedRowError implements Exception {
  const SyncUntrackedRowError(this.message);

  final String message;

  @override
  String toString() => 'SyncUntrackedRowError: $message';
}

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

  @override
  bool operator ==(Object other) =>
      other is ReconcileResult &&
      _listEquals(other.changes, changes) &&
      _mapEquals(other.stamps, stamps) &&
      _listEquals(other.stagedConflicts, stagedConflicts);

  @override
  int get hashCode => Object.hash(
        _hashList(changes),
        _hashMap(stamps),
        _hashList(stagedConflicts),
      );
}

/// Flutter-free sync engine: encodes local rows, decrypts and decodes pulled
/// envelopes, groups concurrent siblings by [SyncRowID], and either returns
/// stamped conflict-free [LedgerChange]s or stages conflicting groups.
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
  /// Throws [SyncPayloadDecryptionError] on AEAD authentication failure and
  /// [SyncPayloadIdentityError] when an authenticated envelope decodes to an
  /// entity that does not belong to it.
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

    for (final entry in byRow.entries) {
      final rowID = entry.key;
      final siblings = entry.value;
      // Reduce the group to its non-dominated frontier: the siblings no other
      // sibling dominates. A strictly superseded sibling (whose version vector
      // some other sibling dominates) is obsolete history, never a genuine
      // concurrent alternative, so it must never reach conflict review.
      final frontier = _nonDominatedFrontier(siblings);
      if (frontier.length == 1) {
        // The sole frontier member dominates every other sibling, so the row
        // is conflict-free.
        final winner = frontier.single;
        changes.add(winner.change);
        stamps[rowID] = winner.envelope.versionVector;
        continue;
      }
      final group = StagedConflict(
        rowID.collection,
        rowID.rowID,
        frontier.map(_toDecodedSibling).toList(),
      );
      stagedConflicts.add(group);
      _staging.stage(group);
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
    // Authenticate the AEAD ciphertext for every envelope, including
    // tombstones, before trusting any lifecycle, collection, or row ID.
    final plaintext = await _cipher.decrypt(
      key: key,
      ciphertext: envelope.ciphertext,
      aad: envelope.aadBytes(),
    );
    if (envelope.lifecycle == SiblingLifecycle.tombstone) {
      if (plaintext.isNotEmpty) {
        throw const SyncPayloadIdentityError(
          'Tombstone payload must be empty.',
        );
      }
      return deleteFor(envelope.collection, envelope.rowID);
    }
    final change = _codec.decodeChange(plaintext);
    if (collectionFor(change) != envelope.collection) {
      throw const SyncPayloadIdentityError(
        'Decoded entity collection does not match the envelope.',
      );
    }
    if (normalizedID(change.targetID) != normalizedID(envelope.rowID)) {
      throw const SyncPayloadIdentityError(
        'Decoded entity ID does not match the envelope row ID.',
      );
    }
    return change;
  }

  // Returns the non-dominated frontier of [siblings]: the subset whose version
  // vectors no other sibling dominates. Exact-duplicate vectors collapse to one
  // representative; a vector survives only if no other distinct vector
  // dominates it.
  static List<_DecodedRow> _nonDominatedFrontier(List<_DecodedRow> siblings) {
    final distinct = <VersionVector, _DecodedRow>{};
    for (final sibling in siblings) {
      distinct.putIfAbsent(
        sibling.envelope.versionVector,
        () => sibling,
      );
    }
    final members = distinct.values.toList();
    return members
        .where(
          (candidate) => members.every(
            (other) =>
                candidate == other ||
                !other.envelope.versionVector
                    .dominates(candidate.envelope.versionVector),
          ),
        )
        .toList();
  }

  static DecodedSibling _toDecodedSibling(_DecodedRow row) => DecodedSibling(
        row.envelope.versionVector,
        row.change,
      );

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
      if (stored == null) {
        throw SyncUntrackedRowError(
          'Cannot encode row $rowID in $collection: the version source '
          'does not track a stored version for it.',
        );
      }
      final version = stored.versionVector;
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
      switch (change) {
        DeleteBudget() ||
        DeleteCategory() ||
        DeleteEntry() ||
        DeletePlan() ||
        DeleteMoneySource() =>
          SiblingLifecycle.tombstone,
        UpsertAccount() ||
        UpsertPocket() ||
        UpsertCategory() ||
        UpsertEntry() ||
        UpsertPlan() ||
        UpsertBudget() =>
          SiblingLifecycle.live,
      };
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

/// A decoded, decrypted sibling carried into a [StagedConflict]: its version
/// vector and the [LedgerChange] decoded from its ciphertext.
///
/// [StagedConflict] carries these decoded values rather than raw envelopes so
/// a later durable store can persist already-decrypted content without a
/// second decryption pass.
@immutable
final class DecodedSibling {
  const DecodedSibling(this.versionVector, this.change);

  final VersionVector versionVector;
  final LedgerChange change;

  @override
  bool operator ==(Object other) =>
      other is DecodedSibling &&
      other.versionVector == versionVector &&
      other.change == change;

  @override
  int get hashCode => Object.hash(versionVector, change);

  @override
  String toString() => 'DecodedSibling($change under $versionVector)';
}

class _DecodedRow {
  const _DecodedRow(this.rowID, this.change, this.envelope);
  final SyncRowID rowID;
  final LedgerChange change;
  final SyncEnvelope envelope;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _hashList<T>(List<T> values) =>
    Object.hashAll(values.map((value) => value.hashCode));

int _hashMap<K, V>(Map<K, V> map) => Object.hashAll(
      map.entries.map((entry) => Object.hash(entry.key, entry.value)),
    );
