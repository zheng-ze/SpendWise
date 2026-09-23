import 'package:sync/sync.dart';

final class ReconciliationSnapshotHasher {
  ReconciliationSnapshotHasher({
    required this.backend,
    required this.credential,
    this.pageLimit,
  });

  final SyncBackend backend;
  final SyncCredential credential;
  final int? pageLimit;

  Future<Map<SyncCollection, String>> hashAll(
    ReconciliationContext context,
  ) async {
    final Map<SyncCollection, String> hashes = <SyncCollection, String>{};
    for (final collection in SyncCollection.values) {
      hashes[collection] = await hashCollection(context, collection);
    }
    return Map<SyncCollection, String>.unmodifiable(hashes);
  }

  Future<String> hashCollection(
    ReconciliationContext context,
    SyncCollection collection,
  ) async {
    String? continuation = context.cursor;
    final List<SyncEnvelope> envelopes = <SyncEnvelope>[];
    while (true) {
      final ReconciliationContext pageContext = continuation == null
          ? _withoutContinuation(context)
          : context.withContinuation(continuation);
      final SyncOutcome<PullResponse> outcome = await backend.pull(
        credential,
        PullRequest.reconciliation(
          collection: collection,
          reconciliation: pageContext,
          pageLimit: pageLimit,
        ),
      );
      final PullResponse page = switch (outcome) {
        SyncSuccess<PullResponse>(:final value) => value,
        SyncFailure<PullResponse>(
          :final code,
          :final message,
          :final retryAfter,
        ) =>
          throw ReconciliationSnapshotException(
            code: code,
            message: message,
            retryAfter: retryAfter,
          ),
      };
      try {
        envelopes.addAll(page.envelopes);
        if (page.endOfSnapshot) return computeSnapshotHash(envelopes);
        final String nextCursor = page.cursor;
        if (nextCursor == continuation) {
          throw const ReconciliationSnapshotException(
            code: 'invalid_request',
            message: 'Reconciliation pull returned a non-progressing cursor.',
          );
        }
        continuation = nextCursor;
      } on FormatException catch (error) {
        throw ReconciliationSnapshotException(
          code: 'invalid_request',
          message: error.message,
        );
      }
    }
  }

  ReconciliationContext _withoutContinuation(ReconciliationContext context) =>
      ReconciliationContext(
        reconciliationID: context.reconciliationID,
        snapshotWatermark: context.snapshotWatermark,
        expiresAt: context.expiresAt,
      );
}

final class ReconciliationSnapshotException implements Exception {
  const ReconciliationSnapshotException({
    required this.code,
    this.message,
    this.retryAfter,
  });

  final String code;
  final String? message;
  final Duration? retryAfter;
}
