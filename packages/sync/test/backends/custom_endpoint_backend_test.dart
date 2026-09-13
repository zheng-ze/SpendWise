import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

void main() {
  final credential = restoreTestCredential(
    deviceID: 'device-a',
    bearerToken: 'secret',
  );

  test('custom backend uses fixed push path and bearer credential', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    });
    final backend = CustomEndpointSyncBackend(
      baseUri: Uri.parse('https://sync.example.test'),
      client: client,
    );

    final outcome = await backend.push(
        credential, PushRequest(envelopes: const <SyncEnvelope>[]));

    expect(outcome, isA<SyncSuccess<PushResponse>>());
    expect(seen.url.path, '/v1/sync/push');
    expect(seen.headers['authorization'], 'Bearer secret');
    expect(jsonDecode(seen.body), {'envelopes': <Object?>[]});
  });

  test('failure body maps to named outcome', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({'failure_code': 'snapshot_hash_mismatch'}),
          409,
          headers: {'content-type': 'application/json'},
        ));
    final backend = CustomEndpointSyncBackend(
      baseUri: Uri.parse('https://sync.example.test'),
      client: client,
    );

    final outcome = await backend.reconcile(
      credential,
      CompleteReconcile(
        collectionHashes: {
          for (final collection in SyncCollection.values) collection: 'hash',
        },
      ),
    );

    expect(outcome, isA<SnapshotHashMismatch<ReconcileResponse>>());
  });

  final failureRows = <_FailureRow<AcknowledgeResponse>>[
    _FailureRow(
        400, 'invalid_request', isA<InvalidRequest<AcknowledgeResponse>>()),
    _FailureRow(401, 'credential_expired',
        isA<CredentialExpired<AcknowledgeResponse>>()),
    _FailureRow(
        403, 'device_retired', isA<DeviceRetired<AcknowledgeResponse>>()),
    _FailureRow(403, 'reconciliation_required',
        isA<ReconciliationRequired<AcknowledgeResponse>>()),
    _FailureRow(409, 'stale_or_invalid_proof',
        isA<StaleOrInvalidProof<AcknowledgeResponse>>()),
    _FailureRow(409, 'snapshot_hash_mismatch',
        isA<SnapshotHashMismatch<AcknowledgeResponse>>()),
    _FailureRow(426, 'protocol_unsupported',
        isA<ProtocolUnsupported<AcknowledgeResponse>>()),
    _FailureRow(429, 'rate_limited', isA<RateLimited<AcknowledgeResponse>>(),
        retryAfterSeconds: 30),
    _FailureRow(503, 'network_unavailable',
        isA<NetworkUnavailable<AcknowledgeResponse>>()),
    _FailureRow(503, 'backend_unavailable',
        isA<BackendUnavailable<AcknowledgeResponse>>(),
        retryAfterSeconds: 30),
  ];

  for (final row in failureRows) {
    test('${row.statusCode} ${row.code} maps to a ${row.expected}', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode(<String, Object?>{'code': row.code, 'message': 'err'}),
            row.statusCode,
            headers: {
              'content-type': 'application/json',
              if (row.retryAfterSeconds != null)
                'retry-after': '${row.retryAfterSeconds}',
            },
          ));
      final backend = CustomEndpointSyncBackend(
        baseUri: Uri.parse('https://sync.example.test'),
        client: client,
      );

      final outcome = await backend.acknowledge(
        credential,
        const AcknowledgeRequest(
          collection: SyncCollection.entries,
          checkpoint: 'checkpoint-1',
        ),
      );

      expect(outcome, row.expected);
      if (row.retryAfterSeconds != null) {
        expect(
          (outcome as SyncFailure<AcknowledgeResponse>).retryAfter,
          Duration(seconds: row.retryAfterSeconds!),
          reason:
              'retry_after_seconds must be parsed from the Retry-After header.',
        );
      }
    });
  }
}

class _FailureRow<T> {
  _FailureRow(this.statusCode, this.code, this.expected,
      {this.retryAfterSeconds});

  final int statusCode;
  final String code;
  final Matcher expected;
  final int? retryAfterSeconds;
}
