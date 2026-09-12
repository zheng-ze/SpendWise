part of '../../sync.dart';

typedef PushHandler = Future<SyncOutcome<PushResponse>> Function(
  SyncCredential credential,
  PushRequest request,
);
typedef PullHandler = Future<SyncOutcome<PullResponse>> Function(
  SyncCredential credential,
  PullRequest request,
);
typedef ReconcileHandler = Future<SyncOutcome<ReconcileResponse>> Function(
  SyncCredential credential,
  ReconcileRequest request,
);
typedef AcknowledgeHandler = Future<SyncOutcome<AcknowledgeResponse>> Function(
  SyncCredential credential,
  AcknowledgeRequest request,
);

/// Lightweight fake for coordinator and adapter-contract tests.
///
/// It deliberately does not simulate server causality, cursor, proof, or GC
/// semantics; those belong in the real server/adapter contract test harness.
final class InMemorySyncBackend implements SyncBackend {
  InMemorySyncBackend({
    PushHandler? onPush,
    PullHandler? onPull,
    ReconcileHandler? onReconcile,
    AcknowledgeHandler? onAcknowledge,
  })  : _onPush = onPush,
        _onPull = onPull,
        _onReconcile = onReconcile,
        _onAcknowledge = onAcknowledge;

  final PushHandler? _onPush;
  final PullHandler? _onPull;
  final ReconcileHandler? _onReconcile;
  final AcknowledgeHandler? _onAcknowledge;

  final List<String> calls = <String>[];

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) async {
    calls.add('push');
    return _onPush?.call(credential, request) ??
        SyncSuccess(PushResponse(const {}));
  }

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async {
    calls.add('pull');
    return _onPull?.call(credential, request) ??
        SyncSuccess(PullResponse(const {}));
  }

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) async {
    calls.add('reconcile');
    return _onReconcile?.call(credential, request) ??
        SyncSuccess(ReconcileResponse(const {}));
  }

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) async {
    calls.add('acknowledge');
    return _onAcknowledge?.call(credential, request) ??
        SyncSuccess(AcknowledgeResponse(const {}));
  }
}
