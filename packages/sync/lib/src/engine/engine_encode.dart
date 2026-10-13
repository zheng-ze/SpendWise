part of '../../sync.dart';

// MARK: - Engine Encode

extension SyncEngineEncode on SyncEngine {
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
