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
      return _failureFromHttp<EnrollmentChallenge>(
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

  @override
  Future<SyncOutcome<DeviceCredential>> completeEnrollment(
    CompleteEnrollmentRequest request,
  ) async {
    final identifier = request.wire['identifier'];
    final otp = request.wire['otp'];
    if (identifier is! String ||
        identifier.isEmpty ||
        otp is! String ||
        !_otpPattern.hasMatch(otp)) {
      return const InvalidRequest<DeviceCredential>(
        message: 'CompleteEnrollmentRequest wire must carry a non-empty '
            '"identifier" email and a 6-digit "otp".',
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
        return _credentialFromVerifyBody(body);
      }
      return _failureFromHttp<DeviceCredential>(
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
}

final RegExp _otpPattern = RegExp(r'^\d{6}$');

SyncOutcome<DeviceCredential> _credentialFromVerifyBody(
  Map<String, Object?> body,
) {
  final accessToken = body['access_token'];
  final user = body['user'];
  var userID = '';
  if (user is Map<Object?, Object?>) {
    final rawID = user['id'];
    if (rawID is String) userID = rawID;
  }
  if (accessToken is! String || accessToken.isEmpty || userID.isEmpty) {
    return const BackendUnavailable<DeviceCredential>(
      message: 'Verify response must carry access_token and user.id.',
    );
  }
  return SyncSuccess<DeviceCredential>(
    DeviceCredential._(deviceID: userID, bearerToken: accessToken),
  );
}
