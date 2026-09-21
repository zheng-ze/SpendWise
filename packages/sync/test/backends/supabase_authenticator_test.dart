import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

SupabaseSyncAuthenticator _authenticator(http.Client client) {
  return SupabaseSyncAuthenticator(
    projectUrl: Uri.parse('https://project.supabase.co'),
    anonKey: 'anon',
    client: client,
  );
}

void main() {
  test('beginEnrollment sends the email identifier and returns a challenge',
      () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response('{}', 200);
    });

    final outcome = await _authenticator(client).beginEnrollment(
      BeginEnrollmentRequest(const {'identifier': 'user@example.com'}),
    );

    expect(outcome, isA<SyncSuccess<EnrollmentChallenge>>());
    expect(seen.method, 'POST');
    expect(seen.url.path, '/auth/v1/otp');
    expect(seen.headers['apikey'], 'anon');
    expect(seen.headers['content-type'], contains('application/json'));
    final body = jsonDecode(seen.body) as Map<String, Object?>;
    expect(body, {'email': 'user@example.com'});
    final challenge = (outcome as SyncSuccess<EnrollmentChallenge>).value;
    expect(challenge.wire['identifier'], 'user@example.com');
  });

  test('beginEnrollment rejects a missing identifier without calling HTTP',
      () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    final outcome = await _authenticator(client).beginEnrollment(
      BeginEnrollmentRequest(const {}),
    );

    expect(outcome, isA<InvalidRequest<EnrollmentChallenge>>());
    expect(called, isFalse);
  });

  test('completeEnrollment accepts a 6-digit OTP and returns a credential',
      () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode(const {
          'access_token': 'access-123',
          'user': {'id': 'user-id-1'},
        }),
        200,
      );
    });

    final outcome = await _authenticator(client).completeEnrollment(
      CompleteEnrollmentRequest(
        const {
          'identifier': 'user@example.com',
          'otp': '123456',
          'deviceId': 'device-1',
        },
      ),
    );

    expect(outcome, isA<SyncSuccess<DeviceCredential>>());
    expect(seen.method, 'POST');
    expect(seen.url.path, '/auth/v1/verify');
    expect(seen.headers['apikey'], 'anon');
    expect(seen.headers['content-type'], contains('application/json'));
    final body = jsonDecode(seen.body) as Map<String, Object?>;
    expect(
      body,
      {'email': 'user@example.com', 'token': '123456', 'type': 'email'},
    );
    final credential = (outcome as SyncSuccess<DeviceCredential>).value;
    expect(
      credential,
      restoreTestCredential(deviceID: 'device-1', bearerToken: 'access-123'),
    );
  });

  test('completeEnrollment rejects a malformed OTP without calling HTTP',
      () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    final outcome = await _authenticator(client).completeEnrollment(
      CompleteEnrollmentRequest(
        const {'identifier': 'user@example.com', 'otp': '12'},
      ),
    );

    expect(outcome, isA<InvalidRequest<DeviceCredential>>());
    expect(called, isFalse);
  });

  test('completeEnrollment maps a non-2xx response to a failure subtype',
      () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(const {'message': 'invalid otp'}),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    final outcome = await _authenticator(client).completeEnrollment(
      CompleteEnrollmentRequest(
        const {
          'identifier': 'user@example.com',
          'otp': '123456',
          'deviceId': 'device-1',
        },
      ),
    );

    expect(outcome, isA<InvalidRequest<DeviceCredential>>());
  });

  test('completeEnrollment maps a 422 GoTrue error to InvalidRequest',
      () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(const {'message': 'validation failed'}),
        422,
        headers: {'content-type': 'application/json'},
      ),
    );

    final outcome = await _authenticator(client).completeEnrollment(
      CompleteEnrollmentRequest(
        const {
          'identifier': 'user@example.com',
          'otp': '123456',
          'deviceId': 'device-1',
        },
      ),
    );

    expect(outcome, isA<InvalidRequest<DeviceCredential>>());
  });

  test('completeEnrollment maps a 429 GoTrue error to RateLimited', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(const {'message': 'too many requests'}),
        429,
        headers: {
          'content-type': 'application/json',
          'retry-after': '30',
        },
      ),
    );

    final outcome = await _authenticator(client).completeEnrollment(
      CompleteEnrollmentRequest(
        const {
          'identifier': 'user@example.com',
          'otp': '123456',
          'deviceId': 'device-1',
        },
      ),
    );

    expect(outcome, isA<RateLimited<DeviceCredential>>());
    expect(
      (outcome as RateLimited<DeviceCredential>).retryAfter,
      const Duration(seconds: 30),
    );
  });

  test('completeEnrollment maps an unexpected status to BackendUnavailable',
      () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(const {'message': 'boom'}),
        500,
        headers: {'content-type': 'application/json'},
      ),
    );

    final outcome = await _authenticator(client).completeEnrollment(
      CompleteEnrollmentRequest(
        const {
          'identifier': 'user@example.com',
          'otp': '123456',
          'deviceId': 'device-1',
        },
      ),
    );

    expect(outcome, isA<BackendUnavailable<DeviceCredential>>());
  });

  test('beginEnrollment rejects an http projectUrl without calling HTTP',
      () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });
    final authenticator = SupabaseSyncAuthenticator(
      projectUrl: Uri.parse('http://project.supabase.co'),
      anonKey: 'anon',
      client: client,
    );

    final outcome = await authenticator.beginEnrollment(
      BeginEnrollmentRequest(const {'identifier': 'user@example.com'}),
    );

    expect(outcome, isA<InvalidRequest<EnrollmentChallenge>>());
    expect(called, isFalse);
  });

  test('completeEnrollment rejects an http projectUrl without calling HTTP',
      () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });
    final authenticator = SupabaseSyncAuthenticator(
      projectUrl: Uri.parse('http://project.supabase.co'),
      anonKey: 'anon',
      client: client,
    );

    final outcome = await authenticator.completeEnrollment(
      CompleteEnrollmentRequest(
        const {
          'identifier': 'user@example.com',
          'otp': '123456',
          'deviceId': 'device-1',
        },
      ),
    );

    expect(outcome, isA<InvalidRequest<DeviceCredential>>());
    expect(called, isFalse);
  });

  test('beginEnrollment maps a network error to NetworkUnavailable', () async {
    final client = MockClient(
      (request) async => throw http.ClientException('offline'),
    );

    final outcome = await _authenticator(client).beginEnrollment(
      BeginEnrollmentRequest(const {'identifier': 'user@example.com'}),
    );

    expect(outcome, isA<NetworkUnavailable<EnrollmentChallenge>>());
  });

  test('completeEnrollment maps a malformed success body to BackendUnavailable',
      () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(const {'unexpected': true}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final outcome = await _authenticator(client).completeEnrollment(
      CompleteEnrollmentRequest(
        const {
          'identifier': 'user@example.com',
          'otp': '123456',
          'deviceId': 'device-1',
        },
      ),
    );

    expect(outcome, isA<BackendUnavailable<DeviceCredential>>());
  });

  test('refreshCredential reports refresh as unsupported', () async {
    final client = MockClient((request) async => http.Response('{}', 200));
    final credential = restoreTestCredential(
      deviceID: 'device-a',
      bearerToken: 'jwt',
    );

    final outcome = await _authenticator(client).refreshCredential(credential);

    expect(outcome, isA<BackendUnavailable<DeviceCredential>>());
    expect(
      (outcome as BackendUnavailable<DeviceCredential>).message,
      contains('not supported'),
    );
  });
}
