part of '../../sync.dart';

/// Supabase Auth (GoTrue) email OTP enrollment adapter.
///
/// Uses the Auth REST surface (`/auth/v1/otp` and `/auth/v1/verify`), not the
/// PostgREST RPCs (`/rest/v1/rpc/...`) that [SupabaseSyncBackend] calls.
final class SupabaseSyncAuthenticator implements SyncAuthenticator {
  SupabaseSyncAuthenticator({
    required this.projectUrl,
    required this.anonKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri projectUrl;
  final String anonKey;
  final http.Client _client;

  @override
  Future<SyncOutcome<EnrollmentChallenge>> beginEnrollment(
    BeginEnrollmentRequest request,
  ) async {
    final schemeFailure = _requireHttps<EnrollmentChallenge>();
    if (schemeFailure != null) return schemeFailure;
    final identifier = request.wire['identifier'];
    if (identifier is! String || identifier.isEmpty) {
      return const InvalidRequest<EnrollmentChallenge>(
        message: 'BeginEnrollmentRequest wire must carry a non-empty '
            '"identifier" email.',
      );
    }
    try {
      final response = await _client.post(
        projectUrl.resolve('/auth/v1/otp'),
        headers: _anonHeaders,
        body: jsonEncode(<String, Object?>{'email': identifier}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SyncSuccess<EnrollmentChallenge>(
          EnrollmentChallenge(<String, Object?>{'identifier': identifier}),
        );
      }
      Map<String, Object?> body;
      try {
        body = _decodeJsonObject(response.body);
      } on FormatException catch (error) {
        return BackendUnavailable<EnrollmentChallenge>(
          message: error.message,
        );
      }
      return _gotrueFailureFromHttp<EnrollmentChallenge>(
        response.statusCode,
        body,
        retryAfterHeader: response.headers['retry-after'],
      );
    } on Object catch (error) {
      return NetworkUnavailable<EnrollmentChallenge>(
        message: error.toString(),
      );
    }
  }

  /// Expects CompleteEnrollmentRequest wire to carry "identifier" (email),
  /// "otp" (6 digits), and "deviceId" (the caller's local device UUID used
  /// for [DeviceCredential.deviceID]).
  @override
  Future<SyncOutcome<DeviceCredential>> completeEnrollment(
    CompleteEnrollmentRequest request,
  ) async {
    final schemeFailure = _requireHttps<DeviceCredential>();
    if (schemeFailure != null) return schemeFailure;
    final identifier = request.wire['identifier'];
    final otp = request.wire['otp'];
    final deviceID = request.wire['deviceId'];
    if (identifier is! String ||
        identifier.isEmpty ||
        otp is! String ||
        !_otpPattern.hasMatch(otp) ||
        deviceID is! String ||
        deviceID.isEmpty) {
      return const InvalidRequest<DeviceCredential>(
        message: 'CompleteEnrollmentRequest wire must carry a non-empty '
            '"identifier" email, a 6-digit "otp", and a non-empty "deviceId".',
      );
    }
    try {
      final response = await _client.post(
        projectUrl.resolve('/auth/v1/verify'),
        headers: _anonHeaders,
        body: jsonEncode(<String, Object?>{
          'email': identifier,
          'token': otp,
          'type': 'email',
        }),
      );
      Map<String, Object?> body;
      try {
        body = _decodeJsonObject(response.body);
      } on FormatException catch (error) {
        return BackendUnavailable<DeviceCredential>(message: error.message);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _credentialFromVerifyBody(body, deviceID);
      }
      return _gotrueFailureFromHttp<DeviceCredential>(
        response.statusCode,
        body,
        retryAfterHeader: response.headers['retry-after'],
      );
    } on Object catch (error) {
      return NetworkUnavailable<DeviceCredential>(
        message: error.toString(),
      );
    }
  }

  @override
  Future<SyncOutcome<DeviceCredential>> refreshCredential(
    DeviceCredential credential,
  ) async {
    return const BackendUnavailable<DeviceCredential>(
      message: 'Credential refresh is not supported for email OTP '
          'enrollment; re-enroll the device to obtain a new credential.',
    );
  }

  Map<String, String> get _anonHeaders => <String, String>{
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

final RegExp _otpPattern = RegExp(r'^\d{6}$');

SyncOutcome<DeviceCredential> _credentialFromVerifyBody(
  Map<String, Object?> body,
  String deviceID,
) {
  final accessToken = body['access_token'];
  if (accessToken is! String || accessToken.isEmpty) {
    return const BackendUnavailable<DeviceCredential>(
      message: 'Verify response must carry access_token.',
    );
  }
  return SyncSuccess<DeviceCredential>(
    DeviceCredential._(deviceID: deviceID, bearerToken: accessToken),
  );
}

/// GoTrue status mapper: only the auth-exchange categories apply here.
SyncFailure<T> _gotrueFailureFromHttp<T>(
  int statusCode,
  Map<String, Object?> body, {
  String? retryAfterHeader,
}) {
  final message = body['message']?.toString();
  final retryAfter = _parseRetryAfter(retryAfterHeader);
  return switch (statusCode) {
    400 || 422 => InvalidRequest<T>(message: message),
    429 => RateLimited<T>(message: message, retryAfter: retryAfter),
    _ => BackendUnavailable<T>(
        message: message ?? 'Unexpected HTTP $statusCode.',
      ),
  };
}
