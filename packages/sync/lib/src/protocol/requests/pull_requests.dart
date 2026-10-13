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

  final String? cursor;

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

final class PullResponse extends _OpaqueWireResponse {
  PullResponse(super.wire);

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

  String get cursor {
    final raw = wire['cursor'];
    if (raw is! String) {
      throw const FormatException(
        'Pull response cursor must be a string.',
      );
    }
    return raw;
  }

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
