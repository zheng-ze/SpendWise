part of '../../sync.dart';

// MARK: - Sync Engine

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

  // MARK: - Reconcile

  /// Decrypts, decodes, groups, and classifies [envelopes].
  ///
  /// Throws [SyncPayloadDecryptionError] on AEAD authentication failure and
  /// [SyncPayloadIdentityError] when an authenticated envelope decodes to an
  /// entity that does not belong to it.
  Future<ReconcileResult> reconcile(Iterable<SyncEnvelope> envelopes) async {
    final key = await _keyAccessor();
    // Materialize once so each decoded row can carry its position in the
    // original input sequence; that index is what `winningInputIndex` reports.
    final inputs = envelopes.toList();
    final decoded = <_DecodedRow>[];
    for (var index = 0; index < inputs.length; index += 1) {
      final envelope = inputs[index];
      final rowID = SyncRowID.of(envelope.collection, envelope.rowID);
      final change = await _decodeRow(key, envelope);
      decoded.add(_DecodedRow(rowID, change, envelope, index));
    }

    final byRow = <SyncRowID, List<_DecodedRow>>{};
    for (final row in decoded) {
      (byRow[row.rowID] ??= <_DecodedRow>[]).add(row);
    }

    final changes = <LedgerChange>[];
    final stamps = <SyncRowID, VersionVector>{};
    final stagedConflicts = <StagedConflict>[];
    final winningInputIndex = <SyncRowID, int>{};

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
        winningInputIndex[rowID] = winner.inputIndex;
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
      winningInputIndex: winningInputIndex,
    );
  }

  // MARK: - Row Decoding

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

  // MARK: - Frontier Reduction

  // Returns the non-dominated frontier of [siblings]: the subset whose version
  // vectors no other sibling dominates. Exact-duplicate vectors collapse to one
  // representative; a vector survives only if no other distinct vector
  // dominates it.
  //
  // Two authenticated envelopes sharing a version vector but decoding to
  // different content is an anomalous state, not a case to resolve by input
  // order: throws [SyncPayloadIdentityError] rather than silently keeping
  // whichever sibling happened to appear first.
  static List<_DecodedRow> _nonDominatedFrontier(List<_DecodedRow> siblings) {
    final distinct = <VersionVector, _DecodedRow>{};
    for (final sibling in siblings) {
      final existing = distinct[sibling.envelope.versionVector];
      if (existing == null) {
        distinct[sibling.envelope.versionVector] = sibling;
        continue;
      }
      if (existing.change != sibling.change) {
        throw SyncPayloadIdentityError(
          'Two authenticated envelopes for the same row share version '
          'vector ${sibling.envelope.versionVector} but decode to '
          'different content.',
        );
      }
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
}

// MARK: - Decoded Row

class _DecodedRow {
  const _DecodedRow(this.rowID, this.change, this.envelope, this.inputIndex);
  final SyncRowID rowID;
  final LedgerChange change;
  final SyncEnvelope envelope;

  /// Position of the originating envelope within the `envelopes` iterable
  /// passed into [SyncEngine.reconcile].
  final int inputIndex;
}
