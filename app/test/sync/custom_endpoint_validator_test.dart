import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/custom_endpoint_validator.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

void main() {
  group('CustomEndpointValidation.validate', () {
    test('accepts an https endpoint with a non-empty host', () {
      final outcome = CustomEndpointValidation.validate(
        'https://sync.example.com/sync',
      );

      expect(outcome, isA<ValidCustomEndpoint>());
      expect(
        (outcome as ValidCustomEndpoint).uri,
        Uri.parse('https://sync.example.com/sync'),
      );
    });

    test('rejects a relative endpoint', () {
      final outcome = CustomEndpointValidation.validate('sync/push');

      expect(outcome, isA<InvalidCustomEndpoint>());
      expect(
        (outcome as InvalidCustomEndpoint).failure.message,
        contains('absolute'),
      );
    });

    test('rejects an http endpoint', () {
      final outcome = CustomEndpointValidation.validate(
        'http://sync.example.com',
      );

      expect(outcome, isA<InvalidCustomEndpoint>());
      expect(
        (outcome as InvalidCustomEndpoint).failure.message,
        contains('https'),
      );
    });

    test('rejects a malformed endpoint', () {
      final outcome = CustomEndpointValidation.validate('https://[::1');

      expect(outcome, isA<InvalidCustomEndpoint>());
    });

    test('rejects a blank endpoint', () {
      final outcome = CustomEndpointValidation.validate('');

      expect(outcome, isA<InvalidCustomEndpoint>());
      expect(
        (outcome as InvalidCustomEndpoint).failure.message,
        contains('absolute'),
      );
    });

    test('rejects a null endpoint', () {
      final outcome = CustomEndpointValidation.validate(null);

      expect(outcome, isA<InvalidCustomEndpoint>());
    });

    test('rejects an https endpoint with an empty host', () {
      final outcome = CustomEndpointValidation.validate('https://');

      expect(outcome, isA<InvalidCustomEndpoint>());
      expect(
        (outcome as InvalidCustomEndpoint).failure.message,
        contains('host'),
      );
    });
  });

  group('SyncBackendResolver custom-endpoint conversion', () {
    const resolver = SyncBackendResolver();

    test('throws the validator failure as its existing exception', () {
      const endpoint = 'sync/push';
      final validation = CustomEndpointValidation.validate(endpoint);
      expect(validation, isA<InvalidCustomEndpoint>());
      final expected = (validation as InvalidCustomEndpoint).failure.message;

      expect(
        () => resolver.resolve(
          SyncMetadataSnapshot(
            backend: SyncBackendKind.custom,
            endpoint: endpoint,
            phase: SyncEnrollmentPhase.notEnrolled,
            writeEnabled: false,
            watermarks: const {},
          ),
        ),
        throwsA(
          isA<SyncBackendConfigurationException>().having(
            (error) => error.message,
            'message',
            expected,
          ),
        ),
      );
    });
  });
}
