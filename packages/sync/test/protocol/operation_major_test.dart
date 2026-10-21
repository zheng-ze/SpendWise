import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('new failure codes match the protocol vocabulary', () {
    expect(DeviceAuthorizationRequired<void>().code,
        'device_authorization_required');
    expect(IncompatibleServer<void>().code, 'incompatible_server');
  });
}
