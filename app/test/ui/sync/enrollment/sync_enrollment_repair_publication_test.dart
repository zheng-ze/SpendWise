import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';
import 'package:spendwise/persistence/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_enrollment_session.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../../support/recording_ledger_store.dart';
import '../../../sync/in_memory_secret_store.dart';

SupabaseConfig get _testConfig => SupabaseConfig(
  projectUrl: Uri.parse('https://test.supabase.co'),
  anonKey: 'test-anon-key',
);

const _stubDeviceSecret = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

String _credentialPayload(String device, String bearer) => base64Url.encode(
  utf8.encode(
    jsonEncode({
      'deviceID': device,
      'bearerToken': base64Url.encode(utf8.encode(bearer)),
    }),
  ),
);

String _e2eKeyPayload() => base64Url.encode(List<int>.filled(32, 7));

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

String? _headerValue(Map<String, String> headers, String name) {
  final wanted = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == wanted) return entry.value;
  }
  return null;
}

final class _ScriptedSyncHttpClient extends http.BaseClient {
  final List<_RecordedHttpRequest> requests = [];
  final Map<String, int> failCounts = {};

  void failNext(String path, {int times = 1}) {
    failCounts[path] = (failCounts[path] ?? 0) + times;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final rawBody = request is http.Request ? request.body : '';
    final body = rawBody.isEmpty
        ? const <String, Object?>{}
        : (jsonDecode(rawBody) as Map<String, Object?>);
    final headers = Map<String, String>.of(request.headers);
    requests.add(
      _RecordedHttpRequest(
        path: request.url.path,
        body: body,
        headers: headers,
      ),
    );
    final remaining = failCounts[request.url.path] ?? 0;
    if (remaining > 0) {
      failCounts[request.url.path] = remaining - 1;
      return _response(500, <String, Object?>{'error': 'injected failure'});
    }
    return _response(200, _stubBody(request.url.path, body, headers));
  }

  Map<String, Object?> _stubBody(
    String path,
    Map<String, Object?> body,
    Map<String, String> headers,
  ) {
    if (path == '/auth/v1/verify') {
      return <String, Object?>{'access_token': 'stub-bearer'};
    }
    if (path == '/functions/v1/sync-device-binding/start') {
      return <String, Object?>{
        'protocol_major': syncOperationMajor,
        'challenge_id': 'challenge-1',
        'expires_at': '2026-09-19T12:00:00.000Z',
      };
    }
    if (path == '/functions/v1/sync-device-binding/verify') {
      return <String, Object?>{
        'protocol_major': syncOperationMajor,
        'access_token': 'stub-bearer',
        'binding_authorization': 'stub-binding-authorization',
        'authorization_expires_at': '2026-09-19T12:00:00.000Z',
      };
    }
    if (path == '/rest/v1/rpc/sync_push') {
      return _appliedPushBody(body);
    }
    if (path == '/rest/v1/rpc/sync_begin_reconcile') {
      return <String, Object?>{
        'reconciliation': <String, Object?>{
          'reconciliation_id': 'recon-1',
          'snapshot_watermark': 'watermark-1',
          'expires_at': '2026-09-19T12:00:00.000Z',
        },
        if (_headerValue(headers, 'X-SpendWise-Binding-Authorization') != null)
          'device_secret': _stubDeviceSecret,
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

  Map<String, Object?> _appliedPushBody(Map<String, Object?> body) {
    final rows = <Object?>[];
    final raw = body['envelopes'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final fields = <String, Object?>{};
        item.forEach((key, value) => fields[key.toString()] = value);
        final versionVector = fields['version_vector'];
        rows.add(<String, Object?>{
          'collection': fields['collection'],
          'row_id': fields['row_id'],
          'sibling_id': fields['sibling_id'],
          'status': 'applied',
          if (versionVector is Map)
            'version_vector': {
              for (final entry in versionVector.entries)
                entry.key.toString(): entry.value,
            },
        });
      }
    }
    return <String, Object?>{'rows': rows};
  }

  http.StreamedResponse _response(int status, Map<String, Object?> json) {
    final bytes = utf8.encode(jsonEncode(json));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  List<_RecordedHttpRequest> callsTo(String path) =>
      requests.where((request) => request.path == path).toList();
}

final class _RepairHarness {
  late LedgerDatabase db;
  late InMemorySecretStore secrets;
  late EventBus bus;
  late Ledger ledger;
  late PersistenceProcessor processor;
  late _ScriptedSyncHttpClient httpClient;
  late ProviderContainer container;
  late AppBoot statusBoot;

  Future<void> build({bool driftStore = false}) async {
    db = LedgerDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    bus = EventBus();
    ledger = Ledger(bus: bus);
    processor = PersistenceProcessor(
      store: driftStore ? DriftLedgerStore(db) : RecordingLedgerStore(),
      bus: bus,
    );
    if (driftStore) await processor.start();
    httpClient = _ScriptedSyncHttpClient();

    late ProviderContainer built;
    Future<SyncEnrollmentSessionResult> opener({
      required String identifier,
      required Future<String> Function(EnrollmentChallenge challenge)
      resolveOtp,
    }) {
      final probe = Provider<Future<SyncEnrollmentSessionResult>>(
        (ref) => openSyncEnrollmentSession(
          ref,
          identifier: identifier,
          resolveOtp: resolveOtp,
          supabaseConfigSource: () => _testConfig,
          httpClient: httpClient,
          secretStore: secrets,
        ),
      );
      return built.read(probe);
    }

    statusBoot = AppBoot(
      createStore: () async => RecordingLedgerStore(),
      seedChanges: () => const [],
      readSyncSnapshot: () => SyncMetadataStore(db).snapshot(),
    );
    built = ProviderContainer(
      overrides: [
        appBootProvider.overrideWith((ref) => statusBoot),
        ledgerDatabaseProvider.overrideWithValue(db),
        syncMetadataStoreProvider.overrideWithValue(SyncMetadataStore(db)),
        ledgerProvider.overrideWithValue(ledger),
        persistenceProcessorProvider.overrideWithValue(processor),
        syncEnrollmentViewModelProvider.overrideWith(
          () => SyncEnrollmentNotifier(
            sessionOpener: opener,
            secretStore: secrets,
            repairMode: true,
          ),
        ),
      ],
    );
    container = built;
  }

  Future<void> dispose() async {
    container.dispose();
    ledger.dispose();
    await bus.dispose();
    await db.close();
  }

  SyncEnrollmentNotifier get notifier =>
      container.read(syncEnrollmentViewModelProvider.notifier);

  SyncEnrollmentState get state =>
      container.read(syncEnrollmentViewModelProvider);

  SyncMetadataStore get metadataStore => SyncMetadataStore(db);

  Future<void> seedHostedSelection() =>
      metadataStore.setBackendSelection(backend: SyncBackendKind.supabase);

  Future<void> seedBoundCredential({String bearer = 'old-bearer'}) async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      _credentialPayload(id, bearer),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    await secrets.write(syncDeviceSecretKey, _stubDeviceSecret);
    await secrets.write(syncE2EKeySecretKey, _e2eKeyPayload());
  }

  Future<void> seedLocalEntry() async {
    const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
    const rowID = '22222222-2222-2222-2222-222222222222';
    ledger.addAccount(
      Account(id: holderID, name: 'holder', type: AccountType.cash),
    );
    ledger.addEntry(
      Entry(
        id: rowID,
        date: DateTime.utc(2024, 3, 15),
        amount: Decimal.parse('-12.50'),
        name: 'Local',
        sourceID: holderID,
        includeInAnalysis: true,
      ),
    );
    await processor.flush();
  }

  Future<void> repairThroughNotifier({
    String identifier = 'user@example.com',
    String otp = '482916',
  }) async {
    final pending = notifier.submitIdentifier(identifier);
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (state.step is ShowOtpEntry) break;
    }
    expect(state.step, isA<ShowOtpEntry>());
    notifier.submitOtp(otp);
    await pending;
  }

  HostedSyncStatus get syncStatus => statusBoot.syncStatus;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('binding repair publishes its proof and deletes the key '
      'before completion', () async {
    final harness = _RepairHarness();
    await harness.build(driftStore: true);
    addTearDown(harness.dispose);
    await harness.seedHostedSelection();
    await harness.seedLocalEntry();
    await harness.metadataStore.enterBindingAuthorizationRequired();
    await harness.secrets.write(syncE2EKeySecretKey, _e2eKeyPayload());
    await harness.notifier.enterRepairMode();

    await harness.repairThroughNotifier();

    expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
    final pushes = harness.httpClient.callsTo('/rest/v1/rpc/sync_push');
    expect(pushes, isNotEmpty);
    expect(pushes.first.body['write_proof'], 'proof-1');
    expect(await harness.secrets.read(syncWriteProofSecretKey), isNull);
    expect(harness.syncStatus, isA<HostedSyncReady>());
  });

  test('session reauth resuming into snapshotInProgress publishes '
      'its proof', () async {
    final harness = _RepairHarness();
    await harness.build(driftStore: true);
    addTearDown(harness.dispose);
    await harness.seedHostedSelection();
    await harness.seedLocalEntry();
    await harness.metadataStore.enterSnapshotInProgress();
    await harness.metadataStore.enterSessionReauthRequired();
    await harness.seedBoundCredential();
    await harness.notifier.enterRepairMode();

    await harness.repairThroughNotifier();

    expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
    final pushes = harness.httpClient.callsTo('/rest/v1/rpc/sync_push');
    expect(pushes, isNotEmpty);
    expect(pushes.first.body['write_proof'], 'proof-1');
    expect(await harness.secrets.read(syncWriteProofSecretKey), isNull);
  });

  test('bearer-only reauth with no proof completes without '
      'publication', () async {
    final harness = _RepairHarness();
    await harness.build(driftStore: true);
    addTearDown(harness.dispose);
    await harness.seedHostedSelection();
    await harness.seedLocalEntry();
    await harness.metadataStore.enterSnapshotInProgress();
    await harness.metadataStore.enterReconciliationComplete();
    await harness.metadataStore.enterGateEnabled();
    await harness.metadataStore.enterSessionReauthRequired();
    await harness.seedBoundCredential();
    await harness.notifier.enterRepairMode();

    await harness.repairThroughNotifier();

    expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    expect(
      harness.httpClient.callsTo('/rest/v1/rpc/sync_push'),
      isEmpty,
      reason: 'no proof means no publication after bearer-only reauth',
    );
    expect(await harness.secrets.read(syncWriteProofSecretKey), isNull);
    expect(harness.syncStatus, isA<HostedSyncReady>());
  });

  test('a repair retry re-checks proof presence before publishing', () async {
    final harness = _RepairHarness();
    await harness.build(driftStore: true);
    addTearDown(harness.dispose);
    await harness.seedHostedSelection();
    await harness.seedLocalEntry();
    await harness.metadataStore.enterSnapshotInProgress();
    await harness.metadataStore.enterReconciliationComplete();
    await harness.metadataStore.enterGateEnabled();
    await harness.metadataStore.enterSessionReauthRequired();
    await harness.seedBoundCredential();
    await harness.notifier.enterRepairMode();
    harness.secrets
      ..readFailure = StateError('transient keychain failure')
      ..readFailureKey = syncWriteProofSecretKey;

    await harness.repairThroughNotifier();

    expect(harness.state.step, isA<ShowProgressResume>());
    expect(harness.state.errorMessage, isNotNull);
    harness.secrets.readFailure = null;

    await harness.notifier.retry();

    expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    expect(
      harness.httpClient.callsTo('/rest/v1/rpc/sync_push'),
      isEmpty,
      reason: 'no proof means the retry must not publish',
    );
  });

  test('bearer-only reauth with a leftover proof publishes and '
      'consumes it', () async {
    final harness = _RepairHarness();
    await harness.build(driftStore: true);
    addTearDown(harness.dispose);
    await harness.seedHostedSelection();
    await harness.seedLocalEntry();
    await harness.metadataStore.enterSnapshotInProgress();
    await harness.metadataStore.enterReconciliationComplete();
    await harness.metadataStore.enterGateEnabled();
    await harness.metadataStore.enterSessionReauthRequired();
    await harness.seedBoundCredential();
    await harness.secrets.write(syncWriteProofSecretKey, 'leftover-9');
    await harness.notifier.enterRepairMode();

    await harness.repairThroughNotifier();

    expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    final pushes = harness.httpClient.callsTo('/rest/v1/rpc/sync_push');
    expect(pushes, isNotEmpty);
    expect(pushes.first.body['write_proof'], 'leftover-9');
    expect(await harness.secrets.read(syncWriteProofSecretKey), isNull);
  });

  test('session reauth converting to binding repair publishes '
      'after reconciliation', () async {
    final harness = _RepairHarness();
    await harness.build(driftStore: true);
    addTearDown(harness.dispose);
    await harness.seedHostedSelection();
    await harness.seedLocalEntry();
    await harness.metadataStore.enterSnapshotInProgress();
    await harness.metadataStore.enterSessionReauthRequired();
    final id = await deviceID(harness.db);
    final credential = const CredentialCodec().restore(
      _credentialPayload(id, 'old-bearer'),
    );
    await harness.secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    await harness.secrets.write(syncE2EKeySecretKey, _e2eKeyPayload());
    await harness.notifier.enterRepairMode();

    await harness.repairThroughNotifier();

    expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
    final pushes = harness.httpClient.callsTo('/rest/v1/rpc/sync_push');
    expect(pushes, isNotEmpty);
    expect(pushes.first.body['write_proof'], 'proof-1');
    expect(await harness.secrets.read(syncWriteProofSecretKey), isNull);
  });

  test('a failed publication shows retry and never shows completion', () async {
    final harness = _RepairHarness();
    await harness.build(driftStore: true);
    addTearDown(harness.dispose);
    await harness.seedHostedSelection();
    await harness.seedLocalEntry();
    await harness.metadataStore.enterBindingAuthorizationRequired();
    await harness.secrets.write(syncE2EKeySecretKey, _e2eKeyPayload());
    harness.httpClient.failNext('/rest/v1/rpc/sync_push');
    await harness.notifier.enterRepairMode();

    await harness.repairThroughNotifier();

    expect(harness.state.step, isA<ShowProgressResume>());
    expect(harness.state.errorMessage, isNotNull);
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );

    await harness.notifier.retry();

    expect(harness.state.step, isA<ShowEnrollmentCompleted>());
    expect(
      harness.httpClient.callsTo('/rest/v1/rpc/sync_push').length,
      greaterThan(1),
    );
    expect(await harness.secrets.read(syncWriteProofSecretKey), isNull);
  });
}
