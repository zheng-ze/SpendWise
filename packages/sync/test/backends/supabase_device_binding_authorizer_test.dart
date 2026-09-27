import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  const anonKey = 'test-anon-key-abc123';
  final projectUrl = Uri.parse('https://project.example.co');

  SupabaseDeviceBindingAuthorizer authorizerWith(http.Client client) {
    return SupabaseDeviceBindingAuthorizer(
      projectUrl: projectUrl,
      anonKey: anonKey,
      client: client,
    );
  }

  String? headerOf(http.Request request, String name) {
    final lower = name.toLowerCase();
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  void expectAnonymousGatewayHeaders(http.Request seen) {
    expect(headerOf(seen, 'authorization'), 'Bearer $anonKey');
    expect(headerOf(seen, 'apikey'), anonKey);
    expect(headerOf(seen, 'content-type'), contains('application/json'));
    expect(headerOf(seen, 'accept'), contains('application/json'));
    expect(headerOf(seen, 'x-device-secret'), isNull);
    expect(headerOf(seen, 'x-binding-authorization'), isNull);
    expect(headerOf(seen, 'authorization'), isNot('Bearer user-session-jwt'));
  }

  group('SupabaseDeviceBindingAuthorizer', () {
    test('startBinding posts request JSON and decodes the challenge', () async {
      final request = StartDeviceBindingRequest(
        identifier: 'user@example.com',
        deviceID: 'device-a',
      );
      final expected = StartDeviceBindingResponse(
        challengeID: 'challenge-1',
        expiresAt: DateTime.utc(2026, 9, 27, 12, 30),
      );
      late http.Request seen;
      final client = MockClient((incoming) async {
        seen = incoming;
        return http.Response(jsonEncode(expected.toWireJson()), 200);
      });

      final outcome = await authorizerWith(client).startBinding(request);

      expect(outcome, isA<SyncSuccess<StartDeviceBindingResponse>>());
      expect(seen.method, 'POST');
      expect(seen.url.path, '/functions/v1/sync-device-binding/start');
      expect(jsonDecode(seen.body), request.toWireJson());
      expectAnonymousGatewayHeaders(seen);
      final value = (outcome as SyncSuccess<StartDeviceBindingResponse>).value;
      expect(value.challengeID, 'challenge-1');
      expect(value.expiresAt, expected.expiresAt);
      expect(value.protocolMajor, syncOperationMajor);
    });

    test('verifyBinding posts request JSON and decodes the credential',
        () async {
      final request = VerifyDeviceBindingRequest(
        challengeID: 'challenge-1',
        identifier: 'user@example.com',
        deviceID: 'device-a',
        otp: '123456',
      );
      final expected = VerifyDeviceBindingResponse(
        accessToken: 'session-jwt',
        bindingAuthorization: 'binding-grant',
        authorizationExpiresAt: DateTime.utc(2026, 9, 27, 13, 30),
      );
      late http.Request seen;
      final client = MockClient((incoming) async {
        seen = incoming;
        return http.Response(jsonEncode(expected.toWireJson()), 200);
      });

      final outcome = await authorizerWith(client).verifyBinding(request);

      expect(outcome, isA<SyncSuccess<VerifyDeviceBindingResponse>>());
      expect(seen.method, 'POST');
      expect(seen.url.path, '/functions/v1/sync-device-binding/verify');
      expect(jsonDecode(seen.body), request.toWireJson());
      expectAnonymousGatewayHeaders(seen);
      final value = (outcome as SyncSuccess<VerifyDeviceBindingResponse>).value;
      expect(value.authorizationExpiresAt, expected.authorizationExpiresAt);
      expect(value.protocolMajor, syncOperationMajor);
    });

    test('non-HTTPS projectUrl returns InvalidRequest without calling HTTP',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls += 1;
        return http.Response('{}', 200);
      });
      final authorizer = SupabaseDeviceBindingAuthorizer(
        projectUrl: Uri.parse('http://project.example'),
        anonKey: anonKey,
        client: client,
      );

      final startOutcome = await authorizer.startBinding(
        StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: 'device-a',
        ),
      );
      final verifyOutcome = await authorizer.verifyBinding(
        VerifyDeviceBindingRequest(
          challengeID: 'challenge-1',
          identifier: 'user@example.com',
          deviceID: 'device-a',
          otp: '123456',
        ),
      );

      expect(startOutcome, isA<InvalidRequest<StartDeviceBindingResponse>>());
      expect(verifyOutcome, isA<InvalidRequest<VerifyDeviceBindingResponse>>());
      expect(calls, 0);
    });

    test('non-2xx responses route through syncFailureFromHttp', () async {
      Future<SyncOutcome<StartDeviceBindingResponse>> startWithStatus(
        int status,
      ) {
        final client = MockClient((_) async {
          return http.Response('{"message":"nope"}', status);
        });
        return authorizerWith(client).startBinding(StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: 'device-a',
        ));
      }

      expect(await startWithStatus(401),
          isA<CredentialExpired<StartDeviceBindingResponse>>());
      expect(await startWithStatus(428),
          isA<DeviceAuthorizationRequired<StartDeviceBindingResponse>>());
      expect(await startWithStatus(426),
          isA<ProtocolUnsupported<StartDeviceBindingResponse>>());

      final rateLimitedClient = MockClient((_) async {
        return http.Response(
          '{"message":"slow down"}',
          429,
          headers: <String, String>{'retry-after': '30'},
        );
      });
      final rateLimitedOutcome = await authorizerWith(rateLimitedClient)
          .verifyBinding(VerifyDeviceBindingRequest(
        challengeID: 'challenge-1',
        identifier: 'user@example.com',
        deviceID: 'device-a',
        otp: '123456',
      ));
      final rateLimited =
          rateLimitedOutcome as RateLimited<VerifyDeviceBindingResponse>;
      expect(rateLimited.retryAfter, const Duration(seconds: 30));
    });

    test('malformed 200 body returns IncompatibleServer', () async {
      for (final raw in <String>['', '[]']) {
        final client = MockClient((_) async {
          return http.Response(raw, 200);
        });
        final outcome =
            await authorizerWith(client).startBinding(StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: 'device-a',
        ));
        expect(outcome, isA<IncompatibleServer<StartDeviceBindingResponse>>(),
            reason: 'body $raw');
      }
    });

    test('200 JSON object failing DTO validation returns IncompatibleServer',
        () async {
      final bodies = <Map<String, Object?>>[
        <String, Object?>{
          'protocol_major': 999,
          'challenge_id': 'challenge-1',
          'expires_at': '2026-09-27T12:30:00Z',
        },
        <String, Object?>{
          'protocol_major': syncOperationMajor,
          'expires_at': '2026-09-27T12:30:00Z',
        },
      ];
      for (final body in bodies) {
        final client = MockClient((_) async {
          return http.Response(jsonEncode(body), 200);
        });
        final outcome =
            await authorizerWith(client).startBinding(StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: 'device-a',
        ));
        expect(outcome, isA<IncompatibleServer<StartDeviceBindingResponse>>(),
            reason: 'body $body');
      }
    });

    test('transport exception returns NetworkUnavailable without secrets',
        () async {
      const secretAnon = 'secret-anon-fixture-key';
      const secretIdentifier = 'secret-identifier-fixture@example.com';
      const secretOtp = '654321';
      final client = MockClient((_) async {
        throw http.ClientException('socket boom');
      });
      final authorizer = SupabaseDeviceBindingAuthorizer(
        projectUrl: projectUrl,
        anonKey: secretAnon,
        client: client,
      );

      final outcome = await authorizer.verifyBinding(VerifyDeviceBindingRequest(
        challengeID: 'challenge-9',
        identifier: secretIdentifier,
        deviceID: 'device-a',
        otp: secretOtp,
      ));

      expect(outcome, isA<NetworkUnavailable<VerifyDeviceBindingResponse>>());
      final message =
          (outcome as NetworkUnavailable<VerifyDeviceBindingResponse>).message;
      expect(message, isNotNull);
      expect(message, isNot(contains(secretAnon)));
      expect(message, isNot(contains(secretIdentifier)));
      expect(message, isNot(contains(secretOtp)));
    });
  });
}
