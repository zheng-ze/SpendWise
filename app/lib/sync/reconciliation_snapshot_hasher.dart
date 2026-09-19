import 'package:sync/sync.dart';

/// Pages one fixed-watermark snapshot and hashes the envelopes fetched.
///
/// Constructed per reconciliation attempt with the attempt's backend and
/// credential. All fetched envelopes stay operation-local: a crash from
/// `snapshotInProgress` discards them and starts a fresh fixed-watermark
/// reconciliation, so no persistent staging schema is added. Hashing never
/// acknowledges, never touches durable normal cursors, and never mutates
/// `LedgerState`.
final class ReconciliationSnapshotHasher {
  ReconciliationSnapshotHasher({
    required this.backend,
    required this.credential,
    this.pageLimit,
  });

  final SyncBackend backend;
  final SyncCredential credential;
  final int? pageLimit;

  /// Hashes all five collections in fixed [SyncCollection.values] order.
  Future<Map<SyncCollection, String>> hashAll(
    ReconciliationContext context,
  ) async {
    final Map<SyncCollection, String> hashes = <SyncCollection, String>{};
    for (final collection in SyncCollection.values) {
      hashes[collection] = await hashCollection(context, collection);
    }
    return Map<SyncCollection, String>.unmodifiable(hashes);
  }

  /// Pages one collection to `endOfSnapshot` under [context] and hashes it.
  ///
  /// Every page carries the same reconciliation ID, watermark, and expiry;
  /// only the nested snapshot-only continuation cursor advances. An empty
  /// collection hashes the canonical empty array, so its key is always
  /// present. A pull failure throws [ReconciliationSnapshotException].
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
      envelopes.addAll(page.envelopes);
      if (page.endOfSnapshot) return computeSnapshotHash(envelopes);
      continuation = page.cursor;
    }
  }

  ReconciliationContext _withoutContinuation(ReconciliationContext context) =>
      ReconciliationContext(
        reconciliationID: context.reconciliationID,
        snapshotWatermark: context.snapshotWatermark,
        expiresAt: context.expiresAt,
      );
}

/// A snapshot pull failed before its collection hashed.
///
/// Carries the failing pull's outcome details so the caller can translate it
/// into its own failure taxonomy.
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
