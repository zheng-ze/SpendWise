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

/// Typed, decoded view of a pull-page wire response.
///
/// This schema is PROVISIONAL: no deployed backend or SQL migration exists
/// yet (see [SupabaseSyncBackend]'s note that its RPC names and signatures
/// must be locked with the SQL migration before shipping). The wire keys are
/// `envelopes` (a JSON array decoded element-wise via
/// [SyncEnvelope.fromWireJson], reusing the `envelopes` key name from
/// [PushRequest.toWireJson]), `cursor` (the next server-assigned pull
/// cursor), and the optional `end_of_snapshot` boolean marker, which is
/// absent or false unless the reconciliation snapshot path sets it.
///
/// A response missing `envelopes` or `cursor`, or holding a malformed
/// envelope element, throws [FormatException] — the same typed error
/// [SyncEnvelope.fromWireJson] already uses for malformed wire JSON — never
/// a raw cast failure.
final class PullResponse extends _OpaqueWireResponse {
  PullResponse(super.wire);

  /// Envelopes decoded element-wise via [SyncEnvelope.fromWireJson].
  List<SyncEnvelope> get envelopes {
    final raw = wire['envelopes'];
    if (raw is! List<Object?>) {
      throw const FormatException(
        'Pull response envelopes must be a list.',
      );
    }
    final decoded = <SyncEnvelope>[];
    for (var index = 0; index < raw.length; index++) {
      final element = raw[index];
      if (element is! Map<Object?, Object?>) {
        throw FormatException(
          'Pull response envelopes[$index] must be an object.',
        );
      }
      final fields = element.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      try {
        decoded.add(SyncEnvelope.fromWireJson(fields));
      } on FormatException catch (error) {
        throw FormatException(
          'Pull response envelopes[$index] is malformed: ${error.message}',
        );
      }
    }
    return List.unmodifiable(decoded);
  }

  /// The next server-assigned pull cursor.
  String get cursor {
    final raw = wire['cursor'];
    if (raw is! String) {
      throw const FormatException(
        'Pull response cursor must be a string.',
      );
    }
    return raw;
  }

  /// Whether this page ends the reconciliation snapshot.
  ///
  /// Absent or false unless the reconciliation snapshot path sets it; a
  /// present non-boolean value throws [FormatException].
  bool get endOfSnapshot {
    final raw = wire['end_of_snapshot'];
    if (raw == null) return false;
    if (raw is! bool) {
      throw const FormatException(
        'Pull response end_of_snapshot must be a boolean.',
      );
    }
    return raw;
  }
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
