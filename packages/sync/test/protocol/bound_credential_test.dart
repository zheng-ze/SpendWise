import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

void main() {
  group('BoundDeviceCredential', () {
    test('bind normalizes the device id', () {
      final bearer = restoreTestCredential(
        deviceID: 'DEVICE-A',
        bearerToken: 'jwt',
      );

      final bound = BoundDeviceCredential.bind(
        bearer,
        deviceSecret: 'secret-1',
      );

      expect(bound.deviceID, 'device-a');
    });

    test('toString redacts bearer and device secret', () {
      const bearer = 'bearer-value-abc';
      const secret = 'device-secret-xyz';
      final bound = BoundDeviceCredential.bind(
        restoreTestCredential(deviceID: 'device-a', bearerToken: bearer),
        deviceSecret: secret,
      );

      expect(bound.toString(), isNot(contains(bearer)));
      expect(bound.toString(), isNot(contains(secret)));
    });
  });
}
