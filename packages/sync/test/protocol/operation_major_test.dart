import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('operation major is 2 and stays distinct from envelope version 1', () {
    expect(syncOperationMajor, 2);
    expect(syncProtocolVersion, 1);
    expect(syncOperationMajor, isNot(syncProtocolVersion));
  });

  test('new failure codes match the protocol vocabulary', () {
    expect(DeviceAuthorizationRequired<void>().code,
        'device_authorization_required');
    expect(IncompatibleServer<void>().code, 'incompatible_server');
  });
}
