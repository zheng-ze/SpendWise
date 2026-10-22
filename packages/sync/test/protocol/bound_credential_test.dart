import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

void main() {
  group('BoundDeviceCredential', () {
    test('layers a device secret on top of a bearer credential', () {
      final bearer = restoreTestCredential(
        deviceID: 'device-a',
        bearerToken: 'jwt',
      );
      final bound = BoundDeviceCredential.bind(
        bearer,
        deviceSecret: 'secret-1',
      );

      expect(bound, isA<SyncCredential>());
      expect(bound, isNot(isA<DeviceCredential>()));
      expect(bound.deviceID, 'device-a');
    });

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

    test('stays distinguishable from the bearer-only credential', () {
      final bearer = restoreTestCredential(
        deviceID: 'device-a',
        bearerToken: 'jwt',
      );
      final bound = BoundDeviceCredential.bind(
        bearer,
        deviceSecret: 'secret-1',
      );

      expect(identical(bearer, bound), isFalse);
      expect(bound == (bearer as Object), isFalse);
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

    test('equal secrets compare equal without leaking', () {
      BoundDeviceCredential bind() => BoundDeviceCredential.bind(
            restoreTestCredential(deviceID: 'device-a', bearerToken: 'jwt'),
            deviceSecret: 'secret-1',
          );

      expect(bind(), bind());
      expect(bind().hashCode, bind().hashCode);
      expect(
        bind(),
        isNot(BoundDeviceCredential.bind(
          restoreTestCredential(deviceID: 'device-a', bearerToken: 'jwt'),
          deviceSecret: 'secret-2',
        )),
      );
    });
  });
}
