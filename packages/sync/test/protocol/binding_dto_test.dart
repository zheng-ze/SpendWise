import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  group('StartDeviceBindingRequest', () {
    test('encodes operation major 2, identifier, and device id', () {
      final wire = StartDeviceBindingRequest(
        identifier: 'user@example.com',
        deviceID: 'DEVICE-A',
      ).toWireJson();

      expect(wire, {
        'protocol_major': 2,
        'identifier': 'user@example.com',
        'device_id': 'device-a',
      });
    });

    test('round-trips through the wire', () {
      final request = StartDeviceBindingRequest(
        identifier: 'user@example.com',
        deviceID: 'device-a',
      );

      expect(
        StartDeviceBindingRequest.fromWireJson(request.toWireJson()),
        request,
      );
    });

    test('rejects a legacy protocol major', () {
      expect(
        () => StartDeviceBindingRequest.fromWireJson(const {
          'protocol_major': 1,
          'identifier': 'user@example.com',
          'device_id': 'device-a',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('StartDeviceBindingResponse', () {
    test('round-trips through the wire', () {
      final response = StartDeviceBindingResponse(
        challengeID: 'challenge-1',
        expiresAt: DateTime.utc(2026, 9, 19, 12),
      );

      final decoded =
          StartDeviceBindingResponse.fromWireJson(response.toWireJson());

      expect(decoded, response);
    });

    test('rejects a legacy protocol major', () {
      expect(
        () => StartDeviceBindingResponse.fromWireJson({
          'protocol_major': 1,
          'challenge_id': 'challenge-1',
          'expires_at': '2026-09-19T12:00:00.000Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a malformed expiry', () {
      expect(
        () => StartDeviceBindingResponse.fromWireJson(const {
          'protocol_major': 2,
          'challenge_id': 'challenge-1',
          'expires_at': 'not-a-timestamp',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('VerifyDeviceBindingRequest', () {
    test('encodes operation major 2 with challenge, identity, and otp', () {
      final wire = VerifyDeviceBindingRequest(
        challengeID: 'challenge-1',
        identifier: 'user@example.com',
        deviceID: 'DEVICE-A',
        otp: '123456',
      ).toWireJson();

      expect(wire, {
        'protocol_major': 2,
        'challenge_id': 'challenge-1',
        'identifier': 'user@example.com',
        'device_id': 'device-a',
        'otp': '123456',
      });
    });

    test('round-trips through the wire', () {
      final request = VerifyDeviceBindingRequest(
        challengeID: 'challenge-1',
        identifier: 'user@example.com',
        deviceID: 'device-a',
        otp: '123456',
      );

      expect(
        VerifyDeviceBindingRequest.fromWireJson(request.toWireJson()),
        request,
      );
    });

    test('rejects a legacy protocol major', () {
      expect(
        () => VerifyDeviceBindingRequest.fromWireJson(const {
          'protocol_major': 1,
          'challenge_id': 'challenge-1',
          'identifier': 'user@example.com',
          'device_id': 'device-a',
          'otp': '123456',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('VerifyDeviceBindingResponse', () {
    VerifyDeviceBindingResponse response() => VerifyDeviceBindingResponse(
          accessToken: 'jwt-access-token',
          bindingAuthorization: 'binding-authorization-value',
          authorizationExpiresAt: DateTime.utc(2026, 9, 19, 12),
        );

    test('round-trips through the wire', () {
      expect(
        VerifyDeviceBindingResponse.fromWireJson(response().toWireJson()),
        response(),
      );
    });

    test('rejects a legacy protocol major', () {
      expect(
        () => VerifyDeviceBindingResponse.fromWireJson(const {
          'protocol_major': 1,
          'access_token': 'jwt',
          'binding_authorization': 'auth',
          'authorization_expires_at': '2026-09-19T12:00:00.000Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('stringification never exposes bearer or authorization', () {
      final printed = response().toString();

      expect(printed, isNot(contains('jwt-access-token')));
      expect(printed, isNot(contains('binding-authorization-value')));
    });

    test('mints an authorization-bearing Begin without exposing the value', () {
      final begin = response().authorizeBegin();

      expect(begin.toString(), isNot(contains('binding-authorization-value')));
      expect(
        begin.toWireJson(),
        const {'action': 'begin_reconcile'},
      );
    });

    test('mints the session credential for the fresh bearer', () {
      final session = response().sessionCredential('DEVICE-A');

      expect(session.deviceID, 'device-a');
      expect(
        session.toString(),
        isNot(anyOf(contains('jwt-access-token'),
            contains('binding-authorization-value'))),
      );
    });
  });

  group('BeginReconcile authorization', () {
    test('a plain Begin carries no authorization field', () {
      expect(
        const BeginReconcile().toWireJson(),
        const {'action': 'begin_reconcile'},
      );
    });

    test('the authorization never appears on the wire, set or not', () {
      const authorization = 'binding-authorization-value';

      expect(
        const BeginReconcile().toWireJson(),
        const {'action': 'begin_reconcile'},
      );
      expect(
        const BeginReconcile(bindingAuthorization: authorization).toWireJson(),
        const {'action': 'begin_reconcile'},
      );
      expect(
        const BeginReconcile(bindingAuthorization: authorization).toString(),
        isNot(contains(authorization)),
      );
    });
  });
}
