import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';
import 'package:spendwise/persistence/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_enrollment_session.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart';
import 'package:spendwise/ui/sync/enrollment/sync_enrollment/sync_enrollment_view_model.dart';
import 'package:sync/sync.dart';

import '../../../support/recording_ledger_store.dart';
import '../../../sync/in_memory_secret_store.dart';

const _identifierField = Key('syncIdentifierField');
const _identifierContinue = Key('syncIdentifierContinue');
const _otpField = Key('syncOtpField');
const _otpSubmit = Key('syncOtpSubmit');
const _resumeRetry = Key('syncResumeRetry');

SupabaseConfig get _testConfig => SupabaseConfig(
  projectUrl: Uri.parse('https://test.supabase.co'),
  anonKey: 'test-anon-key',
);

final class _RecordedHttpRequest {
  const _RecordedHttpRequest({required this.path, required this.body});

  final String path;
  final Map<String, Object?> body;
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
    requests.add(_RecordedHttpRequest(path: request.url.path, body: body));
    final remaining = failCounts[request.url.path] ?? 0;
    if (remaining > 0) {
      failCounts[request.url.path] = remaining - 1;
      return _response(500, <String, Object?>{'error': 'injected failure'});
    }
    return _response(200, _stubBody(request.url.path, body));
  }

  Map<String, Object?> _stubBody(String path, Map<String, Object?> body) {
    if (path == '/auth/v1/verify') {
      return <String, Object?>{'access_token': 'stub-bearer'};
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

final class _HostedHarness {
  late LedgerDatabase db;
  late InMemorySecretStore secrets;
  late EventBus bus;
  late Ledger ledger;
  late PersistenceProcessor processor;
  late _ScriptedSyncHttpClient httpClient;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    bool nullLedger = false,
    bool nullProcessor = false,
    bool driftStore = false,
  }) async {
    db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    secrets = InMemorySecretStore();
    bus = EventBus();
    addTearDown(bus.dispose);
    ledger = Ledger(bus: bus);
    addTearDown(ledger.dispose);
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

    built = ProviderContainer(
      overrides: [
        ledgerDatabaseProvider.overrideWithValue(db),
        syncMetadataStoreProvider.overrideWithValue(SyncMetadataStore(db)),
        ledgerProvider.overrideWithValue(nullLedger ? null : ledger),
        persistenceProcessorProvider.overrideWithValue(
          nullProcessor ? null : processor,
        ),
        syncEnrollmentViewModelProvider.overrideWith(
          () => SyncEnrollmentNotifier(sessionOpener: opener),
        ),
      ],
    );
    container = built;
    addTearDown(built.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: built,
        child: const MaterialApp(home: SyncEnrollmentFlow()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> enrollThroughUi(
    WidgetTester tester, {
    String identifier = 'user@example.com',
    String otp = '482916',
  }) async {
    await tester.tap(find.text('Continue'));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(_identifierField), identifier);
    await tester.pump();
    await tester.tap(find.byKey(_identifierContinue));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(_otpField), otp);
    await tester.pump();
    await tester.tap(find.byKey(_otpSubmit));
    await pumpFrames(tester);
  }

  SyncMetadataStore get metadataStore => SyncMetadataStore(db);

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
}

void main() {
  testWidgets(
    'hosted enrollment reaches gateEnabled and terminal publication',
    (tester) async {
      final harness = _HostedHarness();
      await harness.pump(tester);

      await harness.enrollThroughUi(tester);

      expect(find.text('Sync enrollment complete'), findsOneWidget);
      final snapshot = await harness.metadataStore.snapshot();
      expect(snapshot.backend, SyncBackendKind.supabase);
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isTrue);
      expect(await harness.secrets.read(syncCredentialSecretKey), isNotNull);
      expect(await harness.secrets.read(syncE2EKeySecretKey), isNotNull);
      expect(
        await harness.secrets.read(syncWriteProofSecretKey),
        'proof-1',
        reason: 'an all-noop terminal publication retains the write proof',
      );
      final begins = harness.httpClient.callsTo('/auth/v1/otp');
      expect(begins.single.body['email'], 'user@example.com');
      final completes = harness.httpClient.callsTo('/auth/v1/verify');
      expect(completes.single.body['email'], 'user@example.com');
      expect(completes.single.body['token'], '482916');
      expect(
        harness.httpClient.callsTo('/rest/v1/rpc/sync_begin_reconcile'),
        hasLength(1),
      );
      expect(
        harness.httpClient.callsTo('/rest/v1/rpc/sync_complete_reconcile'),
        hasLength(1),
      );
      final pulls = harness.httpClient.callsTo('/rest/v1/rpc/sync_pull');
      final pulledCollections = pulls
          .map((call) => call.body['collection'])
          .toSet();
      expect(pulledCollections, {
        'money_sources',
        'entries',
        'categories',
        'plans',
        'budgets',
      }, reason: 'reconciliation hashing covers all five collections');
    },
  );

  testWidgets('a failure before credential persistence retries from '
      'identifier entry without resetting the flow', (tester) async {
    final harness = _HostedHarness();
    await harness.pump(tester);
    harness.httpClient.failNext('/auth/v1/otp');

    await tester.tap(find.text('Continue'));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_identifierField), 'user@example.com');
    await tester.pump();
    await tester.tap(find.byKey(_identifierContinue));
    await harness.pumpFrames(tester);

    expect(find.byKey(_identifierField), findsOneWidget);
    expect(
      harness.container.read(syncEnrollmentViewModelProvider).errorMessage,
      isNotNull,
    );
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.notEnrolled,
    );

    await tester.tap(find.byKey(_identifierContinue));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_otpField), '482916');
    await tester.pump();
    await tester.tap(find.byKey(_otpSubmit));
    await harness.pumpFrames(tester);

    expect(
      harness.httpClient.callsTo('/auth/v1/otp'),
      hasLength(2),
      reason:
          'notEnrolled retries from identifier entry with a fresh challenge',
    );
    expect(harness.httpClient.callsTo('/auth/v1/verify'), hasLength(1));
    expect(find.text('Sync enrollment complete'), findsOneWidget);
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  testWidgets('a failure after credential persistence resumes '
      'without re-authenticating', (tester) async {
    final harness = _HostedHarness();
    await harness.pump(tester);

    await tester.tap(find.text('Continue'));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_identifierField), 'user@example.com');
    await tester.pump();
    harness.httpClient.failNext('/rest/v1/rpc/sync_complete_reconcile');
    await tester.tap(find.byKey(_identifierContinue));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_otpField), '482916');
    await tester.pump();
    await tester.tap(find.byKey(_otpSubmit));
    await harness.pumpFrames(tester);

    expect(find.byKey(_resumeRetry), findsOneWidget);
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.snapshotInProgress,
    );

    await tester.tap(find.byKey(_resumeRetry));
    await harness.pumpFrames(tester);

    expect(
      harness.httpClient.callsTo('/auth/v1/otp'),
      hasLength(1),
      reason: 'resume never re-collects identifier or OTP',
    );
    expect(harness.httpClient.callsTo('/auth/v1/verify'), hasLength(1));
    expect(find.text('Sync enrollment complete'), findsOneWidget);
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  testWidgets('credential and E2E key presence without reconciliation '
      'never enables writes', (tester) async {
    final harness = _HostedHarness();
    await harness.pump(tester);

    await tester.tap(find.text('Continue'));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_identifierField), 'user@example.com');
    await tester.pump();
    harness.httpClient.failNext('/rest/v1/rpc/sync_begin_reconcile');
    await tester.tap(find.byKey(_identifierContinue));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_otpField), '482916');
    await tester.pump();
    await tester.tap(find.byKey(_otpSubmit));
    await harness.pumpFrames(tester);

    expect(find.byKey(_resumeRetry), findsOneWidget);
    expect(
      await harness.secrets.read(syncCredentialSecretKey),
      isNotNull,
      reason: 'credential persistence completed before reconciliation ran',
    );
    expect(
      await harness.secrets.read(syncE2EKeySecretKey),
      isNotNull,
      reason: 'E2E key resolution completed before reconciliation ran',
    );
    final snapshot = await harness.metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
    expect(snapshot.writeEnabled, isFalse);

    await tester.tap(find.byKey(_resumeRetry));
    await harness.pumpFrames(tester);

    expect(find.text('Sync enrollment complete'), findsOneWidget);
    expect((await harness.metadataStore.snapshot()).writeEnabled, isTrue);
  });

  testWidgets('a deferred acknowledgement is re-polled until published', (
    tester,
  ) async {
    final harness = _HostedHarness();
    await harness.pump(tester);
    await harness.metadataStore.setPendingAcknowledgement(
      SyncCollection.entries,
      'cursor-1',
    );
    harness.httpClient.failNext('/rest/v1/rpc/sync_acknowledge');

    await harness.enrollThroughUi(tester);

    expect(
      harness.httpClient.callsTo('/rest/v1/rpc/sync_acknowledge').length,
      greaterThanOrEqualTo(2),
      reason: 'EnrollmentSnapshotPending causes a later publisher invocation',
    );
    expect(find.text('Sync enrollment complete'), findsOneWidget);
    expect(
      await harness.metadataStore.pendingAcknowledgement(
        SyncCollection.entries,
      ),
      isNull,
    );
  });

  testWidgets('a not-ready ledger surfaces an error before enrollment begins', (
    tester,
  ) async {
    final harness = _HostedHarness();
    await harness.pump(tester, nullLedger: true);

    await tester.tap(find.text('Continue'));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_identifierField), 'user@example.com');
    await tester.pump();
    await tester.tap(find.byKey(_identifierContinue));
    await harness.pumpFrames(tester);

    expect(
      harness.container.read(syncEnrollmentViewModelProvider).errorMessage,
      isNotNull,
    );
    expect(find.byKey(_identifierField), findsOneWidget);
    expect(harness.httpClient.requests, isEmpty);
  });

  testWidgets('a null persistence processor surfaces a not-ready error '
      'before enrollment begins', (tester) async {
    final harness = _HostedHarness();
    await harness.pump(tester, nullProcessor: true);

    await tester.tap(find.text('Continue'));
    await harness.pumpFrames(tester);
    await tester.enterText(find.byKey(_identifierField), 'user@example.com');
    await tester.pump();
    await tester.tap(find.byKey(_identifierContinue));
    await harness.pumpFrames(tester);

    final state = harness.container.read(syncEnrollmentViewModelProvider);
    expect(state.errorMessage, isNotNull);
    expect(state.inFlight, isFalse);
    expect(find.byKey(_identifierField), findsOneWidget);
    expect(harness.httpClient.requests, isEmpty);
  });

  testWidgets('a genuine push is fully acknowledged and consumes '
      'the write proof', (tester) async {
    final harness = _HostedHarness();
    await harness.pump(tester, driftStore: true);
    await harness.seedLocalEntry();

    await harness.enrollThroughUi(tester);

    expect(find.text('Sync enrollment complete'), findsOneWidget);
    final pushes = harness.httpClient.callsTo('/rest/v1/rpc/sync_push');
    final pushedCollections = {
      for (final call in pushes)
        for (final envelope in (call.body['envelopes'] as List))
          ((envelope as Map)['collection'] as String),
    };
    expect(pushedCollections, containsAll(['money_sources', 'entries']));
    expect(pushes.first.body['write_proof'], 'proof-1');
    expect(
      await harness.secrets.read(syncWriteProofSecretKey),
      isNull,
      reason: 'a genuine acknowledged push consumes the write proof',
    );
    expect(
      await harness.metadataStore.acknowledgedVectors(),
      isNotEmpty,
      reason: 'applied rows retire their acknowledged vectors',
    );
    expect(
      (await harness.metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  testWidgets('a genuine push failure surfaces a resume error and retry '
      'succeeds without re-authenticating', (tester) async {
    final harness = _HostedHarness();
    await harness.pump(tester, driftStore: true);
    await harness.seedLocalEntry();
    harness.httpClient.failNext('/rest/v1/rpc/sync_push');

    await harness.enrollThroughUi(tester);

    expect(find.byKey(_resumeRetry), findsOneWidget);
    final failed = harness.container.read(syncEnrollmentViewModelProvider);
    expect(failed.errorMessage, isNotNull);
    expect(failed.inFlight, isFalse);
    final failedSnapshot = await harness.metadataStore.snapshot();
    expect(failedSnapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(failedSnapshot.writeEnabled, isTrue);
    expect(harness.httpClient.callsTo('/rest/v1/rpc/sync_push'), hasLength(1));

    await tester.tap(find.byKey(_resumeRetry));
    await harness.pumpFrames(tester);

    expect(
      harness.httpClient.callsTo('/auth/v1/otp'),
      hasLength(1),
      reason: 'publication retry never re-collects identifier or OTP',
    );
    expect(harness.httpClient.callsTo('/auth/v1/verify'), hasLength(1));
    expect(
      harness.httpClient.callsTo('/rest/v1/rpc/sync_push').length,
      greaterThan(1),
    );
    expect(find.text('Sync enrollment complete'), findsOneWidget);
    expect(await harness.secrets.read(syncWriteProofSecretKey), isNull);
  });
}
