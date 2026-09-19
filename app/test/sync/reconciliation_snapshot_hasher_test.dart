import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/reconciliation_snapshot_hasher.dart';
import 'package:sync/sync.dart';

ReconciliationContext testContext() => ReconciliationContext(
  reconciliationID: 'recon-42',
  snapshotWatermark: 'watermark-7',
  expiresAt: DateTime.utc(2026, 9, 19, 12),
);

SyncEnvelope testEnvelope(SyncCollection collection, String row) =>
    SyncEnvelope.create(
      protocolVersion: syncProtocolVersion,
      userID: 'user-1',
      collection: collection,
      rowID: row,
      versionVector: VersionVector({'device-a': 1}),
      lifecycle: SiblingLifecycle.live,
      ciphertext: 'cipher-$row',
    );

PullResponse snapshotPage(
  List<SyncEnvelope> envelopes, {
  required String cursor,
  required bool end,
}) => PullResponse(<String, Object?>{
  'envelopes': <Object?>[
    for (final envelope in envelopes) envelope.toWireJson(),
  ],
  'cursor': cursor,
  'end_of_snapshot': end,
});

DeviceCredential testCredential() => const CredentialCodec().restore(
  base64Url.encode(
    utf8.encode(
      jsonEncode({
        'deviceID': 'device-a',
        'bearerToken': base64Url.encode(utf8.encode('bearer')),
      }),
    ),
  ),
);

/// Hand-written fake serving one scripted page queue per collection.
final class ScriptedSnapshotBackend implements SyncBackend {
  ScriptedSnapshotBackend(this.pages);

  final Map<SyncCollection, List<PullResponse>> pages;
  final List<PullRequest> pulls = <PullRequest>[];
  final List<String> calls = <String>[];

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async {
    calls.add('pull');
    pulls.add(request);
    final remaining = pages[request.collection];
    if (remaining == null || remaining.isEmpty) {
      throw StateError('no page scripted for ${request.collection}');
    }
    return SyncSuccess(remaining.removeAt(0));
  }

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) => throw UnimplementedError();

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) => throw UnimplementedError();

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) async {
    calls.add('acknowledge');
    return SyncSuccess(AcknowledgeResponse(const {}));
  }
}

void main() {
  test(
    'hashes five collections in fixed order across multiple pages',
    () async {
      final entries = [
        testEnvelope(SyncCollection.entries, 'row-e1'),
        testEnvelope(SyncCollection.entries, 'row-e2'),
        testEnvelope(SyncCollection.entries, 'row-e3'),
      ];
      final categories = [testEnvelope(SyncCollection.categories, 'row-c1')];
      final budgets = [testEnvelope(SyncCollection.budgets, 'row-b1')];
      final backend = ScriptedSnapshotBackend({
        SyncCollection.moneySources: [
          snapshotPage(const [], cursor: 'cursor-m0', end: true),
        ],
        SyncCollection.entries: [
          snapshotPage(entries.sublist(0, 2), cursor: 'cursor-e1', end: false),
          snapshotPage(entries.sublist(2), cursor: 'cursor-e2', end: false),
          snapshotPage(const [], cursor: 'cursor-e3', end: true),
        ],
        SyncCollection.categories: [
          snapshotPage(categories, cursor: 'cursor-c0', end: true),
        ],
        SyncCollection.plans: [
          snapshotPage(const [], cursor: 'cursor-p0', end: true),
        ],
        SyncCollection.budgets: [
          snapshotPage(budgets, cursor: 'cursor-b1', end: false),
          snapshotPage(const [], cursor: 'cursor-b2', end: true),
        ],
      });
      final hasher = ReconciliationSnapshotHasher(
        backend: backend,
        credential: testCredential(),
      );

      final hashes = await hasher.hashAll(testContext());

      expect(backend.pulls.map((request) => request.collection), [
        SyncCollection.moneySources,
        SyncCollection.entries,
        SyncCollection.entries,
        SyncCollection.entries,
        SyncCollection.categories,
        SyncCollection.plans,
        SyncCollection.budgets,
        SyncCollection.budgets,
      ]);
      expect(hashes[SyncCollection.entries], computeSnapshotHash(entries));
      expect(
        hashes[SyncCollection.categories],
        computeSnapshotHash(categories),
      );
      expect(hashes[SyncCollection.budgets], computeSnapshotHash(budgets));
      expect(
        hashes[SyncCollection.moneySources],
        computeSnapshotHash(const <SyncEnvelope>[]),
      );
      expect(
        hashes[SyncCollection.plans],
        computeSnapshotHash(const <SyncEnvelope>[]),
      );
      expect(hashes.keys.toSet(), SyncCollection.values.toSet());
    },
  );

  test(
    'every page carries the same context with an advancing nested cursor',
    () async {
      final backend = ScriptedSnapshotBackend({
        for (final collection in SyncCollection.values)
          collection: [
            if (collection == SyncCollection.entries)
              snapshotPage(
                [testEnvelope(collection, 'row-e1')],
                cursor: 'cursor-e1',
                end: false,
              ),
            snapshotPage(const [], cursor: 'cursor-end', end: true),
          ],
      });
      final hasher = ReconciliationSnapshotHasher(
        backend: backend,
        credential: testCredential(),
      );

      await hasher.hashAll(testContext());

      for (final request in backend.pulls) {
        expect(
          request.cursor,
          isNull,
          reason: 'reconciliation pulls never use a normal cursor.',
        );
        final context = request.reconciliation;
        expect(context, isNotNull);
        expect(context!.reconciliationID, 'recon-42');
        expect(context.snapshotWatermark, 'watermark-7');
        expect(context.expiresAt, DateTime.utc(2026, 9, 19, 12));
        final wire = request.toWireJson();
        expect(wire.containsKey('cursor'), isFalse);
        expect(wire.containsKey('reconciliation'), isTrue);
      }
      final entriesPulls = backend.pulls
          .where((request) => request.collection == SyncCollection.entries)
          .toList();
      expect(entriesPulls, hasLength(2));
      expect(entriesPulls[0].reconciliation!.cursor, isNull);
      expect(entriesPulls[1].reconciliation!.cursor, 'cursor-e1');
    },
  );

  test('hashing never acknowledges or advances durable state', () async {
    final backend = ScriptedSnapshotBackend({
      for (final collection in SyncCollection.values)
        collection: [snapshotPage(const [], cursor: 'cursor-0', end: true)],
    });
    final hasher = ReconciliationSnapshotHasher(
      backend: backend,
      credential: testCredential(),
    );

    await hasher.hashAll(testContext());

    expect(backend.calls, isNot(contains('acknowledge')));
    expect(
      backend.calls.every((call) => call == 'pull'),
      isTrue,
      reason: 'the hasher only pages the snapshot; it stages nothing.',
    );
  });

  test(
    'an empty snapshot hashes every collection to the empty digest',
    () async {
      final backend = ScriptedSnapshotBackend({
        for (final collection in SyncCollection.values)
          collection: [snapshotPage(const [], cursor: 'cursor-0', end: true)],
      });
      final hasher = ReconciliationSnapshotHasher(
        backend: backend,
        credential: testCredential(),
      );

      final hashes = await hasher.hashAll(testContext());

      expect(hashes, {
        for (final collection in SyncCollection.values)
          collection: 'T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU',
      });
    },
  );

  test('a pull failure surfaces its outcome details', () async {
    final failing = _FailingPullBackend(
      const RateLimited<PullResponse>(
        message: 'slow down',
        retryAfter: Duration(seconds: 30),
      ),
    );
    final hasher = ReconciliationSnapshotHasher(
      backend: failing,
      credential: testCredential(),
    );

    Object? error;
    try {
      await hasher.hashAll(testContext());
      fail('expected a snapshot failure');
    } on ReconciliationSnapshotException catch (e) {
      error = e;
    }

    expect(
      error,
      isA<ReconciliationSnapshotException>()
          .having((e) => e.code, 'code', 'rate_limited')
          .having((e) => e.message, 'message', 'slow down')
          .having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
    );
  });

  test('attempts re-page from scratch without cached snapshot state', () async {
    SyncBackend scripted() => ScriptedSnapshotBackend({
      for (final collection in SyncCollection.values)
        collection: [snapshotPage(const [], cursor: 'cursor-0', end: true)],
    });
    final first = scripted() as ScriptedSnapshotBackend;
    final hasher = ReconciliationSnapshotHasher(
      backend: first,
      credential: testCredential(),
    );

    final firstHashes = await hasher.hashAll(testContext());
    final secondBackend = scripted() as ScriptedSnapshotBackend;
    final secondHashes = await ReconciliationSnapshotHasher(
      backend: secondBackend,
      credential: testCredential(),
    ).hashAll(testContext());

    expect(secondHashes, firstHashes);
    expect(first.pulls, hasLength(SyncCollection.values.length));
    expect(secondBackend.pulls, hasLength(SyncCollection.values.length));
  });

  test(
    'hashCollection re-pages a single collection under one context',
    () async {
      final entries = [testEnvelope(SyncCollection.entries, 'row-e1')];
      final backend = ScriptedSnapshotBackend({
        SyncCollection.entries: [
          snapshotPage(entries, cursor: 'cursor-e1', end: true),
        ],
      });
      final hasher = ReconciliationSnapshotHasher(
        backend: backend,
        credential: testCredential(),
        pageLimit: 50,
      );

      final hash = await hasher.hashCollection(
        testContext(),
        SyncCollection.entries,
      );

      expect(hash, computeSnapshotHash(entries));
      expect(backend.pulls.map((request) => request.collection), [
        SyncCollection.entries,
      ]);
      expect(backend.pulls.single.toWireJson()['page_limit'], 50);
    },
  );
}

final class _FailingPullBackend implements SyncBackend {
  _FailingPullBackend(this.failure);

  final SyncOutcome<PullResponse> failure;

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async => failure;

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) => throw UnimplementedError();

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) => throw UnimplementedError();

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) => throw UnimplementedError();
}
