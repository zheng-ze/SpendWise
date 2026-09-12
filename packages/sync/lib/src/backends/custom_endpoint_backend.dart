part of '../../sync.dart';

/// Prototype implementation of the fixed custom HTTP endpoint adapter.
///
/// Request field names beyond the fixed paths must be verified against the
/// authoritative sync protocol before shipping.
final class CustomEndpointSyncBackend implements SyncBackend {
  CustomEndpointSyncBackend({
    required this.baseUri,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) =>
      _post<PushResponse>(
        credential,
        '/v1/sync/push',
        request.toWireJson(),
        PushResponse.new,
      );

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) =>
      _post<PullResponse>(
        credential,
        '/v1/sync/pull',
        request.toWireJson(),
        PullResponse.new,
      );

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) =>
      _post<ReconcileResponse>(
        credential,
        '/v1/sync/reconcile',
        request.toWireJson(),
        ReconcileResponse.new,
      );

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) =>
      _post<AcknowledgeResponse>(
        credential,
        '/v1/sync/acknowledge',
        request.toWireJson(),
        AcknowledgeResponse.new,
      );

  Future<SyncOutcome<T>> _post<T>(
    SyncCredential credential,
    String path,
    Map<String, Object?> requestBody,
    T Function(Map<String, Object?>) decode,
  ) async {
    final deviceCredential = _requireDeviceCredential(credential);
    try {
      final response = await _client.post(
        baseUri.resolve(path),
        headers: _authorizationHeaders(deviceCredential),
        body: jsonEncode(requestBody),
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
