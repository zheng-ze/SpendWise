part of '../../sync.dart';

/// Prototype Supabase/PostgREST adapter using server-side RPCs.
///
/// RPC names are a proposal from the implementation plan. Their signatures and
/// returned error bodies must be locked with the SQL migration before shipping.
final class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend({
    required this.projectUrl,
    required this.anonKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri projectUrl;
  final String anonKey;
  final http.Client _client;

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) =>
      _rpc<PushResponse>(
        credential,
        'sync_push',
        request.toWireJson(),
        PushResponse.new,
      );

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) =>
      _rpc<PullResponse>(
        credential,
        'sync_pull',
        request.toWireJson(),
        PullResponse.new,
      );

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) {
    final rpc = switch (request) {
      BeginReconcile() => 'sync_begin_reconcile',
      CompleteReconcile() => 'sync_complete_reconcile',
    };
    final body = Map<String, Object?>.of(request.toWireJson())
      ..remove('action');
    return _rpc<ReconcileResponse>(
      credential,
      rpc,
      body,
      ReconcileResponse.new,
    );
  }

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) =>
      _rpc<AcknowledgeResponse>(
        credential,
        'sync_acknowledge',
        request.toWireJson(),
        AcknowledgeResponse.new,
      );

  Future<SyncOutcome<T>> _rpc<T>(
    SyncCredential credential,
    String functionName,
    Map<String, Object?> requestBody,
    T Function(Map<String, Object?>) decode,
  ) async {
    final deviceCredential = _requireDeviceCredential(credential);
    final headers = _authorizationHeaders(deviceCredential)
      ..['apikey'] = anonKey;
    final outgoingBody = Map<String, Object?>.of(requestBody)
      ..['device_id'] = deviceCredential.deviceID;
    try {
      final response = await _client.post(
        projectUrl.resolve('/rest/v1/rpc/$functionName'),
        headers: headers,
        body: jsonEncode(outgoingBody),
      );
      Map<String, Object?> body;
      try {
        body = _decodeJsonObject(response.body);
      } on FormatException catch (error) {
        return BackendUnavailable<T>(message: error.message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SyncSuccess<T>(decode(body));
      }
      return _failureFromHttp<T>(
        response.statusCode,
        body,
        retryAfterHeader: response.headers['retry-after'],
      );
    } on Object catch (error) {
      return NetworkUnavailable<T>(message: error.toString());
    }
  }
}
