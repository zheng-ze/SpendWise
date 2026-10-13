part of '../../../sync.dart';

// MARK: - Pull Request

final class PullRequest {
  const PullRequest({
    required this.collection,
    this.cursor,
    this.pageLimit,
  }) : reconciliation = null;

  const PullRequest.reconciliation({
    required this.collection,
    required this.reconciliation,
    this.pageLimit,
  }) : cursor = null;

  final SyncCollection collection;

  /// Ordinary durable pull cursor. Never set on a reconciliation pull.
  final String? cursor;

  /// Snapshot-only reconciliation context. Never set on an ordinary pull.
  ///
  /// The two constructors keep ordinary and reconciliation pulls mutually
  /// exclusive: a reconciliation pull carries the nested `reconciliation`
  /// object (with the continuation cursor inside it) instead of a top-level
  /// `cursor`.
  final ReconciliationContext? reconciliation;
  final int? pageLimit;

  Map<String, Object?> toWireJson() {
    final reconciliation = this.reconciliation;
    if (reconciliation != null) {
      return <String, Object?>{
        'collection': collection.wireName,
        'reconciliation': reconciliation.toWireJson(),
        if (pageLimit != null) 'page_limit': pageLimit,
      };
    }
    return <String, Object?>{
      'collection': collection.wireName,
      if (cursor != null) 'cursor': cursor,
      if (pageLimit != null) 'page_limit': pageLimit,
    };
  }
}

// MARK: - Pull Response

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
