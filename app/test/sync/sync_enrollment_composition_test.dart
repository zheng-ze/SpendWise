import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_enrollment_composition.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

import '../support/recording_ledger_store.dart';
import 'in_memory_secret_store.dart';

SupabaseConfig get _testConfig => SupabaseConfig(
  projectUrl: Uri.parse('https://test.supabase.co'),
  anonKey: 'test-anon-key',
);

String _credentialPayload(String device, String bearer) => base64Url.encode(
  utf8.encode(
    jsonEncode({
      'deviceID': device,
      'bearerToken': base64Url.encode(utf8.encode(bearer)),
    }),
  ),
);

final class _RecordedHttpRequest {
  const _RecordedHttpRequest({
    required this.path,
    required this.body,
    required this.headers,
  });

  final String path;
  final Map<String, Object?> body;
  final Map<String, String> headers;
}

final class _FakeSyncHttpClient extends http.BaseClient {
  final String bearer = 'stub-bearer';
  final List<_RecordedHttpRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final rawBody = request is http.Request ? request.body : '';
    final body = rawBody.isEmpty
        ? const <String, Object?>{}
        : (jsonDecode(rawBody) as Map<String, Object?>);
    requests.add(
      _RecordedHttpRequest(
        path: request.url.path,
        body: body,
        headers: Map<String, String>.of(request.headers),
      ),
    );
    return _response(_stubBody(request.url.path));
  }

  Map<String, Object?> _stubBody(String path) {
    if (path == '/auth/v1/verify') {
      return <String, Object?>{'access_token': bearer};
    }
    if (path == '/rest/v1/rpc/sync_begin_reconcile') {
      return <String, Object?>{
        'reconciliation': <String, Object?>{
          'reconciliation_id': 'recon-1',
          'snapshot_watermark': 'watermark-1',
          'expires_at': '2026-09-19T12:00:00.000Z',
        },
      };
    }
    if (path == '/rest/v1/rpc/sync_complete_reconcile') {
      return <String, Object?>{'write_proof': 'proof-1'};
    }
    if (path == '/rest/v1/rpc/sync_pull') {
      return <String, Object?>{
        'envelopes': <Object?>[],
        'cursor': 'cursor-0',
        'end_of_snapshot': true,
      };
    }
    return const <String, Object?>{};
  }

  http.StreamedResponse _response(Map<String, Object?> json) {
    final bytes = utf8.encode(jsonEncode(json));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  List<_RecordedHttpRequest> callsTo(String path) =>
      requests.where((request) => request.path == path).toList();
}

void main() {
  late LedgerDatabase db;
  late InMemorySecretStore secrets;
  late EventBus bus;
  late Ledger ledger;
  late PersistenceProcessor processor;
  late _FakeSyncHttpClient httpClient;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    bus = EventBus();
    ledger = Ledger(bus: bus);
    processor = PersistenceProcessor(store: RecordingLedgerStore(), bus: bus);
    httpClient = _FakeSyncHttpClient();
  });

  tearDown(() async {
    await bus.dispose();
    ledger.dispose();
    await db.close();
  });

  Future<SyncEnrollmentComposition> compose({
    Ledger? ledgerOverride,
    PersistenceProcessor? processorOverride,
    bool overrideLedger = true,
    bool overrideProcessor = true,
    bool forceNullLedger = false,
    bool forceNullProcessor = false,
    String identifier = 'user@example.com',
    Future<String> Function(EnrollmentChallenge)? resolveOtp,
    Future<Uint8List> Function()? resolveE2EKey,
    SupabaseConfig? Function()? configSource,
  }) {
    final container = ProviderContainer(
      overrides: [
        ledgerDatabaseProvider.overrideWithValue(db),
        if (overrideLedger)
          ledgerProvider.overrideWithValue(
            forceNullLedger ? null : (ledgerOverride ?? ledger),
          ),
        if (overrideProcessor)
          persistenceProcessorProvider.overrideWithValue(
            forceNullProcessor ? null : (processorOverride ?? processor),
          ),
      ],
    );
    addTearDown(container.dispose);
    final probe = Provider<Future<SyncEnrollmentComposition>>(
      (ref) => composeSyncEnrollment(
        ref,
        identifier: identifier,
        resolveOtp: resolveOtp ?? (_) async => '482916',
        resolveE2EKey: resolveE2EKey,
        secretStore: secrets,
        supabaseConfigSource: configSource ?? () => _testConfig,
        httpClient: httpClient,
      ),
    );
    return container.read(probe);
  }

  Future<SyncEnrollmentReady> composeReady({
    String identifier = 'user@example.com',
    Future<String> Function(EnrollmentChallenge)? resolveOtp,
    Future<Uint8List> Function()? resolveE2EKey,
  }) async {
    await SyncMetadataStore(db)
        .setBackendSelection(backend: SyncBackendKind.supabase);
    final composition = await compose(
      identifier: identifier,
      resolveOtp: resolveOtp,
      resolveE2EKey: resolveE2EKey,
    );
    return composition as SyncEnrollmentReady;
  }

  test('begin request carries the submitted identifier', () async {
    final ready = await composeReady(identifier: 'user@example.com');

    final request = ready.enrollmentService.buildBeginRequest();

    expect(request.wire['identifier'], 'user@example.com');
  });

  test('complete request carries the challenge identifier, OTP, and database deviceID', () async {
    final ready = await composeReady(identifier: 'user@example.com');
    final challenge = EnrollmentChallenge(const {
      'identifier': 'challenge@example.com',
    });

    final request = await ready.enrollmentService.buildCompleteRequest(
      challenge,
    );

    expect(request.wire['identifier'], 'challenge@example.com');
    expect(request.wire['otp'], '482916');
    expect(request.wire['deviceId'], await deviceID(db));
    expect(request.wire.keys.toSet(), {'identifier', 'otp', 'deviceId'});
  });

  test(
    'authenticator and backend carry the validated Supabase configuration',
    () async {
      final ready = await composeReady();

      expect(ready.authenticator, isA<SupabaseSyncAuthenticator>());
      expect(ready.authenticator.projectUrl, _testConfig.projectUrl);
      expect(ready.authenticator.anonKey, _testConfig.anonKey);
      expect(ready.backend, isA<SupabaseSyncBackend>());
      final backend = ready.backend as SupabaseSyncBackend;
      expect(backend.projectUrl, _testConfig.projectUrl);
      expect(backend.anonKey, _testConfig.anonKey);
    },
  );

  test('service, coordinator, and publisher share one SecretStore', () async {
    final ready = await composeReady();

    expect(
      identical(ready.enrollmentService.secretStore, ready.secretStore),
      isTrue,
    );

    final metadataStore = SyncMetadataStore(db);
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.reconciliationComplete,
    );
    await metadataStore.setWriteEnabled(true);
    await secrets.write(syncWriteProofSecretKey, 'proof-1');

    final publishResult = await ready.snapshotPublisher.publish();

    expect(publishResult, isA<EnrollmentSnapshotPublished>());
    expect(secrets.reads, contains(syncWriteProofSecretKey));

    await secrets.write(
      syncCredentialSecretKey,
      _credentialPayload(await deviceID(db), 'stub-bearer'),
    );
    await metadataStore.setPendingAcknowledgement(
      SyncCollection.entries,
      'cursor-1',
    );

    await ready.coordinator.recoverPendingAcknowledgements();

    final acknowledges = httpClient.callsTo('/rest/v1/rpc/sync_acknowledge');
    expect(acknowledges, hasLength(1));
    expect(acknowledges.single.headers['authorization'], 'Bearer stub-bearer');
    expect(
      await metadataStore.pendingAcknowledgement(SyncCollection.entries),
      isNull,
    );
  });

  test(
    'production E2E resolver produces SyncCipher.keyByteCount bytes',
    () async {
      final key = await resolveProductionSyncE2EKey();

      expect(key.length, SyncCipher.keyByteCount);
    },
  );

  test('injected deterministic key is durably stored and validates', () async {
    final key = Uint8List.fromList(
      List<int>.generate(SyncCipher.keyByteCount, (index) => 255 - index),
    );
    final ready = await composeReady(
      identifier: 'user@example.com',
      resolveE2EKey: () async => key,
    );

    await ready.enrollmentService.enroll();

    final stored = await secrets.read(syncE2EKeySecretKey);
    expect(stored, isNotNull);
    expect(decodeAndValidateSyncE2EKey(stored!), key);
    expect(
      (await SyncMetadataStore(db).snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
    final begins = httpClient.callsTo('/auth/v1/otp');
    expect(begins.single.body['email'], 'user@example.com');
    final completes = httpClient.callsTo('/auth/v1/verify');
    expect(completes.single.body['email'], 'user@example.com');
    expect(completes.single.body['token'], '482916');
  });

  test('null ledger emits not-ready without touching the network', () async {
    await SyncMetadataStore(db)
        .setBackendSelection(backend: SyncBackendKind.supabase);

    final composition = await compose(forceNullLedger: true);

    expect(composition, isA<SyncEnrollmentNotReady>());
    final notReady = composition as SyncEnrollmentNotReady;
    expect(notReady.ledgerReady, isFalse);
    expect(notReady.persistenceReady, isTrue);
    expect(httpClient.requests, isEmpty);
  });

  test(
    'null persistence processor emits not-ready without touching the network',
    () async {
      await SyncMetadataStore(db)
          .setBackendSelection(backend: SyncBackendKind.supabase);

      final composition = await compose(forceNullProcessor: true);

      expect(composition, isA<SyncEnrollmentNotReady>());
      final notReady = composition as SyncEnrollmentNotReady;
      expect(notReady.ledgerReady, isTrue);
      expect(notReady.persistenceReady, isFalse);
      expect(httpClient.requests, isEmpty);
    },
  );

  test('missing backend selection is a configuration error', () async {
    final composition = await compose();

    expect(composition, isA<SyncEnrollmentConfigurationError>());
    expect(httpClient.requests, isEmpty);
  });

  test(
    'custom backend selection is a configuration error, not a fallback',
    () async {
      await SyncMetadataStore(db).setBackendSelection(
        backend: SyncBackendKind.custom,
        endpoint: 'https://custom.example.com',
      );

      final composition = await compose();

      expect(composition, isA<SyncEnrollmentConfigurationError>());
      expect(httpClient.requests, isEmpty);
    },
  );

  test('missing Supabase configuration is a configuration error', () async {
    await SyncMetadataStore(db)
        .setBackendSelection(backend: SyncBackendKind.supabase);

    final composition = await compose(configSource: () => null);

    expect(composition, isA<SyncEnrollmentConfigurationError>());
    expect(httpClient.requests, isEmpty);
  });

  test('invalid Supabase configuration is a configuration error', () async {
    await SyncMetadataStore(db)
        .setBackendSelection(backend: SyncBackendKind.supabase);

    final composition = await compose(
      configSource: () => SupabaseConfig(
        projectUrl: Uri.parse('http://insecure.example.com'),
        anonKey: 'test-anon-key',
      ),
    );

    expect(composition, isA<SyncEnrollmentConfigurationError>());
    expect(httpClient.requests, isEmpty);
  });
}
