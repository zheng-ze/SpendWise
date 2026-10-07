part of '../../sync.dart';

/// Device-binding enrollment adapter for the `sync-device-binding` Edge
/// Function.
///
/// Uses the anonymous Edge gateway contract (`Authorization: Bearer <anonKey>`
/// plus `apikey: <anonKey>`), never a user session bearer or device secret:
/// this class runs before any of those exist.
final class SupabaseDeviceBindingAuthorizer implements DeviceBindingAuthorizer {
  SupabaseDeviceBindingAuthorizer({
    required this.projectUrl,
    required this.anonKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri projectUrl;
  final String anonKey;
  final http.Client _client;

  @override
  Future<SyncOutcome<StartDeviceBindingResponse>> startBinding(
    StartDeviceBindingRequest request,
  ) async {
    final schemeFailure = _requireHttps<StartDeviceBindingResponse>();
    if (schemeFailure != null) return schemeFailure;
    try {
      final response = await _client.post(
        projectUrl.resolve('/functions/v1/sync-device-binding/start'),
        headers: _anonHeaders,
        body: jsonEncode(request.toWireJson()),
      );
      if (response.statusCode >= _httpSuccessMin &&
          response.statusCode < _httpSuccessExclusiveMax) {
        try {
          final body = _decodeJsonObject(response.body);
          return SyncSuccess<StartDeviceBindingResponse>(
            StartDeviceBindingResponse.fromWireJson(body),
          );
        } on FormatException {
          return const IncompatibleServer<StartDeviceBindingResponse>(
            message:
                'Device-binding endpoint returned an incompatible response.',
          );
        }
      }
      return _bindingFailureFromHttp<StartDeviceBindingResponse>(response);
    } on Object {
      return const NetworkUnavailable<StartDeviceBindingResponse>(
        message: 'Network error contacting the device-binding endpoint.',
      );
    }
  }

  @override
  Future<SyncOutcome<VerifyDeviceBindingResponse>> verifyBinding(
    VerifyDeviceBindingRequest request,
  ) async {
    final schemeFailure = _requireHttps<VerifyDeviceBindingResponse>();
    if (schemeFailure != null) return schemeFailure;
    try {
      final response = await _client.post(
        projectUrl.resolve('/functions/v1/sync-device-binding/verify'),
        headers: _anonHeaders,
        body: jsonEncode(request.toWireJson()),
      );
      if (response.statusCode >= _httpSuccessMin &&
          response.statusCode < _httpSuccessExclusiveMax) {
        try {
          final body = _decodeJsonObject(response.body);
          return SyncSuccess<VerifyDeviceBindingResponse>(
            VerifyDeviceBindingResponse.fromWireJson(body),
          );
        } on FormatException {
          return const IncompatibleServer<VerifyDeviceBindingResponse>(
            message:
                'Device-binding endpoint returned an incompatible response.',
          );
        }
      }
      return _bindingFailureFromHttp<VerifyDeviceBindingResponse>(response);
    } on Object {
      return const NetworkUnavailable<VerifyDeviceBindingResponse>(
        message: 'Network error contacting the device-binding endpoint.',
      );
    }
  }

  Map<String, String> get _anonHeaders => <String, String>{
        'Authorization': 'Bearer $anonKey',
        'apikey': anonKey,
        'content-type': 'application/json',
        'accept': 'application/json',
      };

  SyncFailure<T>? _requireHttps<T>() {
    if (projectUrl.scheme != 'https') {
      return InvalidRequest<T>(
        message: 'projectUrl must use https.',
      );
    }
    return null;
  }
}

SyncFailure<T> _bindingFailureFromHttp<T>(http.Response response) {
  Map<String, Object?> body;
  try {
    body = _decodeJsonObject(response.body);
  } on FormatException {
    body = const <String, Object?>{};
  }
  return syncFailureFromHttp<T>(
    response.statusCode,
    body,
    retryAfterHeader: response.headers['retry-after'],
  );
}
