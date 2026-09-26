import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  group('syncFailureFromHttp', () {
    test('401 maps only to credential_expired', () {
      final failure = syncFailureFromHttp<PushResponse>(401, const {});

      expect(failure, isA<CredentialExpired<PushResponse>>());
      expect(failure.code, 'credential_expired');
    });

    test('428 maps only to device_authorization_required', () {
      final byStatus = syncFailureFromHttp<PushResponse>(428, const {});
      final byCode = syncFailureFromHttp<PushResponse>(
        400,
        const {'code': 'device_authorization_required'},
      );

      expect(byStatus, isA<DeviceAuthorizationRequired<PushResponse>>());
      expect(byStatus.code, 'device_authorization_required');
      expect(byCode, isA<DeviceAuthorizationRequired<PushResponse>>());
    });

    test('explicit 426 stays protocol_unsupported', () {
      final byStatus = syncFailureFromHttp<PushResponse>(426, const {});
      final byCode = syncFailureFromHttp<PushResponse>(
        400,
        const {'code': 'protocol_unsupported'},
      );

      expect(byStatus, isA<ProtocolUnsupported<PushResponse>>());
      expect(byCode, isA<ProtocolUnsupported<PushResponse>>());
    });

    test('incompatible_server is client-detected, never a status route', () {
      final failure = syncFailureFromHttp<PushResponse>(
        400,
        const {'code': 'incompatible_server'},
      );

      expect(failure, isA<IncompatibleServer<PushResponse>>());
      expect(failure.code, 'incompatible_server');
      expect(
        syncFailureFromHttp<PushResponse>(426, const {}),
        isNot(isA<IncompatibleServer<PushResponse>>()),
      );
    });

    test('a named code wins over the status route', () {
      final failure = syncFailureFromHttp<PushResponse>(
        428,
        const {'code': 'credential_expired'},
      );

      expect(failure, isA<CredentialExpired<PushResponse>>());
    });

    test('existing vocabulary keeps mapping through the shared mapper', () {
      expect(
        syncFailureFromHttp<void>(400, const {'code': 'invalid_request'}),
        isA<InvalidRequest<void>>(),
      );
      expect(
        syncFailureFromHttp<void>(403, const {'code': 'device_retired'}),
        isA<DeviceRetired<void>>(),
      );
      expect(
        syncFailureFromHttp<void>(
            409, const {'code': 'reconciliation_required'}),
        isA<ReconciliationRequired<void>>(),
      );
      expect(
        syncFailureFromHttp<void>(429, const {'code': 'rate_limited'}),
        isA<RateLimited<void>>(),
      );
    });

    test('unknown failures stay backend_unavailable', () {
      final failure = syncFailureFromHttp<PushResponse>(418, const {});

      expect(failure, isA<BackendUnavailable<PushResponse>>());
    });
  });
}
