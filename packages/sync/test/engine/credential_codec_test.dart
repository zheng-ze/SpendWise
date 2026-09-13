import 'dart:convert';

import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  final codec = const CredentialCodec();
  const deviceID = 'deadbeef-0000-1111-2222-333333333333';
  const bearer = 'eyJhbGciOiJIUzI1NiJ9.payload.signature-secret-part';

  DeviceCredential credential() =>
      DeviceCredential.testing(deviceID: deviceID, bearerToken: bearer);

  group('round-trip', () {
    test('exports and restores an authenticated credential', () {
      final payload = codec.export(credential());
      final restored = codec.restore(payload);
      expect(restored, credential());
    });

    test('restores a normalized device id', () {
      final payload = codec.export(
        DeviceCredential.testing(deviceID: 'DEADBEEF', bearerToken: bearer),
      );
      expect(codec.restore(payload).deviceID, 'deadbeef');
    });

    test('rejects a non-JSON payload', () {
      expect(() => codec.restore('not a payload'),
          throwsA(isA<FormatException>()));
    });
  });

  group('bearer opacity', () {
    test('the exported payload never contains the raw bearer', () {
      final payload = codec.export(credential());
      expect(payload, isNot(contains(bearer)));
    });

    test('toString redacts the bearer', () {
      expect(credential().toString(), isNot(contains(bearer)));
    });

    test('a bearer-bearing malformed payload never leaks the bearer', () {
      // Valid base64url that decodes to the bearer string; jsonDecode then
      // fails, and the thrown message must not echo the bearer substring.
      final payload = base64Url.encode(utf8.encode(bearer));
      expect(
        () => codec.restore(payload),
        throwsA(
          isA<FormatException>().having(
            (error) => error.toString(),
            'toString',
            isNot(contains(bearer)),
          ),
        ),
      );
    });
  });
}
