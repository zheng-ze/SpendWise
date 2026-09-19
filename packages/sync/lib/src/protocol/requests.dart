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

/// Per-row outcome of a push call, decoded from [PushResponse.rowOutcomes].
///
/// Every variant carries the submitted row's `sibling_id`, so a caller can
/// verify the entry belongs to the sibling it actually submitted before
/// retiring any acknowledged vector.
sealed class PushRowOutcome {
  const PushRowOutcome({required this.siblingID});

  final String siblingID;
}

/// The server applied the submitted sibling.
final class PushApplied extends PushRowOutcome {
  const PushApplied({
    required super.siblingID,
    required this.resultingFrontier,
  });

  final VersionVector resultingFrontier;
}

/// The submitted sibling was already present on the server.
final class PushAlreadyPresent extends PushRowOutcome {
  const PushAlreadyPresent({
    required super.siblingID,
    required this.resultingFrontier,
  });

  final VersionVector resultingFrontier;
}

/// The server rejected the submitted sibling.
final class PushRejected extends PushRowOutcome {
  const PushRejected({required super.siblingID});
}

/// Typed, decoded view of a push wire response.
///
/// This schema is PROVISIONAL: no deployed backend or SQL migration exists
/// yet (see [SupabaseSyncBackend]'s note that its RPC names and signatures
/// must be locked with the SQL migration before shipping). The wire key is
/// `rows` (a JSON array of per-row objects), where each entry carries
/// `row_id`, `collection`, `sibling_id`, and a `status` of `applied`,
/// `already_present`, or `rejected`, plus a `version_vector` object on
/// `applied`/`already_present` entries holding the resulting causal
/// frontier.
///
/// A response missing `rows`, or holding a malformed entry — a missing or
/// unrecognized `status`, a missing `version_vector` on an
/// applied/already_present entry, or a missing/non-string `sibling_id` —
/// throws [FormatException], never a raw cast failure.
final class PushResponse extends _OpaqueWireResponse {
  PushResponse(super.wire);

  /// Per-row outcomes keyed by [SyncRowID].
  Map<SyncRowID, PushRowOutcome> get rowOutcomes {
    final raw = wire['rows'];
    if (raw is! List<Object?>) {
      throw const FormatException(
        'Push response rows must be a list.',
      );
    }
    final decoded = <SyncRowID, PushRowOutcome>{};
    for (var index = 0; index < raw.length; index++) {
      final element = raw[index];
      if (element is! Map<Object?, Object?>) {
        throw FormatException(
          'Push response rows[$index] must be an object.',
        );
      }
      final fields = element.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      try {
        final entry = _decodePushRow(fields);
        decoded[entry.key] = entry.value;
      } on FormatException catch (error) {
        throw FormatException(
          'Push response rows[$index] is malformed: ${error.message}',
        );
      }
    }
    return Map.unmodifiable(decoded);
  }
}

MapEntry<SyncRowID, PushRowOutcome> _decodePushRow(
    Map<String, Object?> fields) {
  final row = SyncRowID.of(
    SyncCollection.fromWireName(_expectString(fields, 'collection')),
    _expectString(fields, 'row_id'),
  );
  final siblingID = _expectString(fields, 'sibling_id');
  final status = _expectString(fields, 'status');
  switch (status) {
    case 'applied':
      return MapEntry(
        row,
        PushApplied(
          siblingID: siblingID,
          resultingFrontier: _expectPushFrontier(fields),
        ),
      );
    case 'already_present':
      return MapEntry(
        row,
        PushAlreadyPresent(
          siblingID: siblingID,
          resultingFrontier: _expectPushFrontier(fields),
        ),
      );
    case 'rejected':
      return MapEntry(row, PushRejected(siblingID: siblingID));
    default:
      throw FormatException('Unknown push status: $status');
  }
}

VersionVector _expectPushFrontier(Map<String, Object?> fields) {
  final raw = fields['version_vector'];
  if (raw is! Map<Object?, Object?>) {
    throw const FormatException(
      'Push response version_vector must be an object.',
    );
  }
  return VersionVector.fromWireCounters(
    raw.map<String, Object?>((key, value) => MapEntry(key.toString(), value)),
  );
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
