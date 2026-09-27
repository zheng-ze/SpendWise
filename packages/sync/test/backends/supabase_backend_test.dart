import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

const _deviceID = 'device-a';
const _bearerToken = 'test-bearer-token-abc';
const _deviceSecret = 'test-device-secret-xyz';
const _bindingAuthorization = 'test-binding-authorization-123';

BoundDeviceCredential _boundCredential() => bindTestCredential(
      deviceID: _deviceID,
      bearerToken: _bearerToken,
      deviceSecret: _deviceSecret,
    );

DeviceCredential _bareCredential() => restoreTestCredential(
      deviceID: _deviceID,
      bearerToken: _bearerToken,
    );

SupabaseSyncBackend _backend(MockClient client) => SupabaseSyncBackend(
      projectUrl: Uri.parse('https://project.supabase.co'),
      anonKey: 'anon',
      client: client,
    );

String? _headerOf(http.BaseRequest request, String name) {
  final wanted = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == wanted) return entry.value;
  }
  return null;
}

void main() {
  group('bound operations send the device secret and protocol major', () {
    test('push carries device_id, protocol_major, and device secret', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      final outcome = await _backend(client).push(
        _boundCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );

      expect(outcome, isA<SyncSuccess<PushResponse>>());
      expect(seen.url.path, '/rest/v1/rpc/sync_push');
      expect(seen.headers['apikey'], 'anon');
      expect(_headerOf(seen, 'authorization'), 'Bearer $_bearerToken');
      expect(
        _headerOf(seen, 'X-SpendWise-Device-Secret'),
        _deviceSecret,
      );
      expect(
        _headerOf(seen, 'X-SpendWise-Binding-Authorization'),
        isNull,
      );
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['device_id'], _deviceID);
      expect(body['protocol_major'], 2);
    });

    test(
        'bound begin reconcile sends the device secret, never the binding '
        'authorization header', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      final outcome = await _backend(client).reconcile(
        _boundCredential(),
        const BeginReconcile(),
      );

      expect(outcome, isA<SyncSuccess<ReconcileResponse>>());
      expect(seen.url.path, '/rest/v1/rpc/sync_begin_reconcile');
      expect(seen.headers['apikey'], 'anon');
      expect(_headerOf(seen, 'authorization'), 'Bearer $_bearerToken');
      expect(
        _headerOf(seen, 'X-SpendWise-Device-Secret'),
        _deviceSecret,
      );
      expect(
        _headerOf(seen, 'X-SpendWise-Binding-Authorization'),
        isNull,
      );
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['device_id'], _deviceID);
      expect(body['protocol_major'], 2);
    });

    test('complete reconcile carries all five collection hashes', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      final outcome = await _backend(client).reconcile(
        _boundCredential(),
        CompleteReconcile(
          collectionHashes: {
            for (final collection in SyncCollection.values) collection: 'hash',
          },
        ),
      );

      expect(outcome, isA<SyncSuccess<ReconcileResponse>>());
      expect(seen.url.path, '/rest/v1/rpc/sync_complete_reconcile');
      expect(
        _headerOf(seen, 'X-SpendWise-Device-Secret'),
        _deviceSecret,
      );
      expect(
        _headerOf(seen, 'X-SpendWise-Binding-Authorization'),
        isNull,
      );
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['device_id'], _deviceID);
      expect(body['protocol_major'], 2);
      final hashes = body['collection_hashes'] as Map<String, dynamic>;
      expect(hashes, hasLength(SyncCollection.values.length));
      for (final collection in SyncCollection.values) {
        expect(hashes[collection.wireName], 'hash');
      }
    });

    test('acknowledge carries the caller device_id and protocol major',
        () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      final outcome = await _backend(client).acknowledge(
        _boundCredential(),
        const AcknowledgeRequest(
          collection: SyncCollection.entries,
          checkpoint: 'checkpoint-1',
        ),
      );

      expect(outcome, isA<SyncSuccess<AcknowledgeResponse>>());
      expect(seen.url.path, '/rest/v1/rpc/sync_acknowledge');
      expect(
        _headerOf(seen, 'X-SpendWise-Device-Secret'),
        _deviceSecret,
      );
      expect(
        _headerOf(seen, 'X-SpendWise-Binding-Authorization'),
        isNull,
      );
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['device_id'], _deviceID);
      expect(body['protocol_major'], 2);
    });

    test('reconciliation pull forwards the nested context to sync_pull',
        () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'envelopes': <Object?>[],
            'cursor': 'cursor-1',
            'end_of_snapshot': true,
          }),
          200,
        );
      });

      final outcome = await _backend(client).pull(
        _boundCredential(),
        PullRequest.reconciliation(
          collection: SyncCollection.budgets,
          reconciliation: ReconciliationContext(
            reconciliationID: 'recon-42',
            snapshotWatermark: 'watermark-7',
            expiresAt: DateTime.utc(2026, 9, 19, 12),
          ),
        ),
      );

      expect(outcome, isA<SyncSuccess<PullResponse>>());
      expect(seen.url.path, '/rest/v1/rpc/sync_pull');
      expect(
        _headerOf(seen, 'X-SpendWise-Device-Secret'),
        _deviceSecret,
      );
      expect(
        _headerOf(seen, 'X-SpendWise-Binding-Authorization'),
        isNull,
      );
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['collection'], 'budgets');
      expect(body.containsKey('cursor'), isFalse);
      expect(
        (body['reconciliation'] as Map<String, dynamic>)['reconciliation_id'],
        'recon-42',
      );
      expect(body['device_id'], _deviceID);
      expect(body['protocol_major'], 2);
    });
  });

  group('authorization-bearing begin reconcile', () {
    test(
        'sends the binding authorization header and keeps it out of the '
        'body', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      final outcome = await _backend(client).reconcile(
        _bareCredential(),
        const BeginReconcile(bindingAuthorization: _bindingAuthorization),
      );

      expect(outcome, isA<SyncSuccess<ReconcileResponse>>());
      expect(seen.url.path, '/rest/v1/rpc/sync_begin_reconcile');
      expect(seen.headers['apikey'], 'anon');
      expect(_headerOf(seen, 'authorization'), 'Bearer $_bearerToken');
      expect(
        _headerOf(seen, 'X-SpendWise-Binding-Authorization'),
        _bindingAuthorization,
      );
      expect(
        _headerOf(seen, 'X-SpendWise-Device-Secret'),
        isNull,
      );
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'protocol_major', 'device_id'});
      expect(body['protocol_major'], 2);
      expect(body['device_id'], _deviceID);
      expect(seen.body, isNot(contains(_bindingAuthorization)));
    });
  });

  group('credential and operation mode mismatches', () {
    test(
        'bare credential on a bound operation returns InvalidRequest '
        'without an HTTP call', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });

      final outcome = await _backend(client).push(
        _bareCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );

      expect(outcome, isA<InvalidRequest<PushResponse>>());
      expect(calls, 0);
    });

    test(
        'bound credential on an authorization-bearing begin returns '
        'InvalidRequest without an HTTP call', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });

      final outcome = await _backend(client).reconcile(
        _boundCredential(),
        const BeginReconcile(bindingAuthorization: _bindingAuthorization),
      );

      expect(outcome, isA<InvalidRequest<ReconcileResponse>>());
      expect(calls, 0);
    });

    test('invalid JSON 2xx body returns IncompatibleServer', () async {
      final client = MockClient((request) async {
        return http.Response('not-json{{', 200);
      });

      final outcome = await _backend(client).push(
        _boundCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );

      expect(outcome, isA<IncompatibleServer<PushResponse>>());
    });
  });

  group('failure mapping follows the shared v2 matrix', () {
    test('401 maps to CredentialExpired', () async {
      final client = MockClient((request) async {
        return http.Response('{}', 401);
      });

      final outcome = await _backend(client).push(
        _boundCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );

      expect(outcome, isA<CredentialExpired<PushResponse>>());
    });

    test('401 with a non-JSON body still maps to CredentialExpired', () async {
      final client = MockClient((request) async {
        return http.Response('Bad Gateway', 401);
      });

      final outcome = await _backend(client).push(
        _boundCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );

      expect(outcome, isA<CredentialExpired<PushResponse>>());
    });

    test('428 maps to DeviceAuthorizationRequired', () async {
      final client = MockClient((request) async {
        return http.Response('{}', 428);
      });

      final outcome = await _backend(client).pull(
        _boundCredential(),
        const PullRequest(collection: SyncCollection.entries),
      );

      expect(outcome, isA<DeviceAuthorizationRequired<PullResponse>>());
    });

    test('426 maps to ProtocolUnsupported', () async {
      final client = MockClient((request) async {
        return http.Response('{}', 426);
      });

      final outcome = await _backend(client).acknowledge(
        _boundCredential(),
        const AcknowledgeRequest(
          collection: SyncCollection.entries,
          checkpoint: 'checkpoint-1',
        ),
      );

      expect(
        outcome,
        isA<ProtocolUnsupported<AcknowledgeResponse>>(),
      );
    });

    test('429 with retry-after maps to RateLimited with the retry delay',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          '{}',
          429,
          headers: {'retry-after': '7'},
        );
      });

      final outcome = await _backend(client).push(
        _boundCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );

      final failure = outcome as RateLimited<PushResponse>;
      expect(failure.retryAfter, const Duration(seconds: 7));
    });
  });

  group('failure messages never carry secrets', () {
    test('InvalidRequest and NetworkUnavailable messages are redacted',
        () async {
      var calls = 0;
      final noCallClient = MockClient((request) async {
        calls++;
        return http.Response('{}', 200);
      });
      final throwingClient = MockClient((request) async {
        throw const SocketLikeException();
      });

      final invalid = await _backend(noCallClient).push(
        _bareCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );
      final invalidBegin = await _backend(noCallClient).reconcile(
        _boundCredential(),
        const BeginReconcile(bindingAuthorization: _bindingAuthorization),
      );
      final unreachable = await _backend(throwingClient).push(
        _boundCredential(),
        PushRequest(envelopes: const <SyncEnvelope>[]),
      );

      expect(calls, 0);
      expect(invalidBegin, isA<InvalidRequest<ReconcileResponse>>());
      for (final message in [
        (invalid as SyncFailure<PushResponse>).message,
        (invalidBegin as SyncFailure<ReconcileResponse>).message,
        (unreachable as SyncFailure<PushResponse>).message,
      ]) {
        expect(message, isNot(contains(_bearerToken)));
        expect(message, isNot(contains(_deviceSecret)));
        expect(message, isNot(contains(_bindingAuthorization)));
      }
      expect(unreachable, isA<NetworkUnavailable<PushResponse>>());
    });
  });
}

final class SocketLikeException implements Exception {
  const SocketLikeException();

  @override
  String toString() => 'SocketException: connection refused';
}
