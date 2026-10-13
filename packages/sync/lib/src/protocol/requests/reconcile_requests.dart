part of '../../../sync.dart';

// MARK: - Reconciliation Context

final class ReconciliationContext {
  const ReconciliationContext({
    required this.reconciliationID,
    required this.snapshotWatermark,
    required this.expiresAt,
    this.cursor,
  })  : assert(reconciliationID.length > 0),
        assert(snapshotWatermark.length > 0);

  final String reconciliationID;
  final String snapshotWatermark;
  final DateTime expiresAt;
  final String? cursor;

  ReconciliationContext withContinuation(String cursor) =>
      ReconciliationContext(
        reconciliationID: reconciliationID,
        snapshotWatermark: snapshotWatermark,
        expiresAt: expiresAt,
        cursor: cursor,
      );

  Map<String, Object?> toWireJson() => <String, Object?>{
        'reconciliation_id': reconciliationID,
        'snapshot_watermark': snapshotWatermark,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        if (cursor != null) 'cursor': cursor,
      };

  factory ReconciliationContext.fromWireJson(Map<String, Object?> value) {
    final reconciliationID = _expectString(value, 'reconciliation_id');
    final snapshotWatermark = _expectString(value, 'snapshot_watermark');
    if (reconciliationID.isEmpty || snapshotWatermark.isEmpty) {
      throw const FormatException(
        'Reconciliation context IDs must not be empty.',
      );
    }
    final expiresRaw = _expectString(value, 'expires_at');
    final expiresAt = DateTime.tryParse(expiresRaw)?.toUtc();
    if (expiresAt == null) {
      throw const FormatException(
        'Reconciliation expires_at must be an RFC 3339 timestamp.',
      );
    }
    final rawCursor = value['cursor'];
    String? cursor;
    if (rawCursor != null) {
      if (rawCursor is! String) {
        throw const FormatException(
          'Reconciliation cursor must be a string.',
        );
      }
      cursor = rawCursor;
    }
    return ReconciliationContext(
      reconciliationID: reconciliationID,
      snapshotWatermark: snapshotWatermark,
      expiresAt: expiresAt,
      cursor: cursor,
    );
  }
}

// MARK: - Reconcile Requests

sealed class ReconcileRequest {
  const ReconcileRequest();
  Map<String, Object?> toWireJson();
}

final class BeginReconcile extends ReconcileRequest {
  const BeginReconcile({String? bindingAuthorization})
      : _bindingAuthorization = bindingAuthorization;

  final String? _bindingAuthorization;

  @override
  Map<String, Object?> toWireJson() => const <String, Object?>{
        'action': 'begin_reconcile',
      };

  @override
  String toString() => 'BeginReconcile(bindingAuthorization: '
      '${_bindingAuthorization == null ? 'absent' : '<redacted>'})';
}

final class CompleteReconcile extends ReconcileRequest {
  CompleteReconcile({required Map<SyncCollection, String> collectionHashes})
      : collectionHashes = Map.unmodifiable(collectionHashes) {
    final missing = SyncCollection.values
        .where((item) => !this.collectionHashes.containsKey(item));
    if (missing.isNotEmpty ||
        this.collectionHashes.length != SyncCollection.values.length) {
      throw ArgumentError(
          'Complete reconciliation requires exactly all five collection hashes.');
    }
  }

  final Map<SyncCollection, String> collectionHashes;

  @override
  Map<String, Object?> toWireJson() => <String, Object?>{
        'action': 'complete_reconcile',
        'collection_hashes': <String, Object?>{
          for (final collection in SyncCollection.values)
            collection.wireName: collectionHashes[collection]!,
        },
      };
}

// MARK: - Reconcile Response

final class ReconcileResponse extends _OpaqueWireResponse {
  ReconcileResponse(super.wire);

  ReconciliationContext get reconciliationContext {
    final raw = wire['reconciliation'];
    if (raw is! Map<Object?, Object?>) {
      throw const FormatException(
        'Reconcile response reconciliation must be an object.',
      );
    }
    return ReconciliationContext.fromWireJson(
      raw.map<String, Object?>((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
