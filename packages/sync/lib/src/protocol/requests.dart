part of '../../sync.dart';

/// The confirmed sync protocol major.
///
/// Set to `1` per `docs/sync-protocol.md` §6: "Every request declares exactly
/// one protocol major", with no second major defined anywhere in the design
/// document. This is the confirmed protocol major, not a provisional value.
const int syncProtocolVersion = 1;

final class PushRequest {
  PushRequest({required Iterable<SyncEnvelope> envelopes, this.writeProof})
      : envelopes = List.unmodifiable(envelopes);

  final List<SyncEnvelope> envelopes;
  final String? writeProof;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'envelopes': <Object?>[for (final item in envelopes) item.toWireJson()],
        if (writeProof != null) 'write_proof': writeProof,
      };
}

final class PullRequest {
  const PullRequest({
    required this.collection,
    this.cursor,
    this.pageLimit,
  });

  final SyncCollection collection;
  final String? cursor;
  final int? pageLimit;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'collection': collection.wireName,
        if (cursor != null) 'cursor': cursor,
        if (pageLimit != null) 'page_limit': pageLimit,
      };
}

sealed class ReconcileRequest {
  const ReconcileRequest();
  Map<String, Object?> toWireJson();
}

final class BeginReconcile extends ReconcileRequest {
  const BeginReconcile();

  @override
  Map<String, Object?> toWireJson() => const <String, Object?>{
        'action': 'begin_reconcile',
      };
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

final class AcknowledgeRequest {
  const AcknowledgeRequest({
    required this.collection,
    required this.checkpoint,
  });

  final SyncCollection collection;
  final String checkpoint;

  Map<String, Object?> toWireJson() => <String, Object?>{
        'collection': collection.wireName,
        'checkpoint': checkpoint,
      };
}

abstract base class _OpaqueWireResponse {
  _OpaqueWireResponse(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}

final class PushResponse extends _OpaqueWireResponse {
  PushResponse(super.wire);
}

final class PullResponse extends _OpaqueWireResponse {
  PullResponse(super.wire);
}

final class ReconcileResponse extends _OpaqueWireResponse {
  ReconcileResponse(super.wire);
}

final class AcknowledgeResponse extends _OpaqueWireResponse {
  AcknowledgeResponse(super.wire);
}

final class BeginEnrollmentRequest {
  BeginEnrollmentRequest(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}

final class EnrollmentChallenge {
  EnrollmentChallenge(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}

final class CompleteEnrollmentRequest {
  CompleteEnrollmentRequest(Map<String, Object?> wire)
      : wire = Map.unmodifiable(wire);
  final Map<String, Object?> wire;
}
