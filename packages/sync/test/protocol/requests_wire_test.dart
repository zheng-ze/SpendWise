import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('pull uses optional page_limit and cursor wire fields', () {
    expect(
      const PullRequest(collection: SyncCollection.entries).toWireJson(),
      {'collection': 'entries'},
    );

    expect(
      const PullRequest(
        collection: SyncCollection.entries,
        cursor: 'cursor-1',
        pageLimit: 250,
      ).toWireJson(),
      {
        'collection': 'entries',
        'cursor': 'cursor-1',
        'page_limit': 250,
      },
    );
  });

  test('acknowledge uses checkpoint, not cursor', () {
    expect(
      const AcknowledgeRequest(
        collection: SyncCollection.entries,
        checkpoint: 'checkpoint-1',
      ).toWireJson(),
      {
        'collection': 'entries',
        'checkpoint': 'checkpoint-1',
      },
    );
  });

  test('known push and reconcile wire keys match the protocol vocabulary', () {
    expect(
      PushRequest(envelopes: const [], writeProof: 'proof').toWireJson(),
      {
        'envelopes': <Object?>[],
        'write_proof': 'proof',
      },
    );

    expect(
      CompleteReconcile(
        collectionHashes: {
          for (final collection in SyncCollection.values) collection: 'hash',
        },
      ).toWireJson(),
      {
        'action': 'complete_reconcile',
        'collection_hashes': {
          for (final collection in SyncCollection.values)
            collection.wireName: 'hash',
        },
      },
    );
  });

  test(
      'PushRequest.toWireJson carries only envelopes, and write_proof only when supplied',
      () {
    final withoutProof =
        PushRequest(envelopes: const <SyncEnvelope>[]).toWireJson();
    expect(withoutProof, {'envelopes': <Object?>[]});
    expect(withoutProof.containsKey('write_proof'), isFalse,
        reason:
            'write_proof must be absent, not merely null, when unprovided.');

    final withProof =
        PushRequest(envelopes: const <SyncEnvelope>[], writeProof: 'proof')
            .toWireJson();
    expect(withProof.keys.toList(), <String>['envelopes', 'write_proof']);
    expect(
      withProof,
      {
        'envelopes': <Object?>[],
        'write_proof': 'proof',
      },
    );
  });

  test(
      'PullRequest.toWireJson carries only collection, plus cursor/page_limit only when supplied',
      () {
    final minimal =
        const PullRequest(collection: SyncCollection.entries).toWireJson();
    expect(minimal.keys.toList(), <String>['collection']);
    expect(
      minimal,
      {'collection': 'entries'},
    );

    final withCursor = const PullRequest(
      collection: SyncCollection.entries,
      cursor: 'cursor-1',
    ).toWireJson();
    expect(withCursor.keys.toList(), <String>['collection', 'cursor']);
    expect(withCursor, {'collection': 'entries', 'cursor': 'cursor-1'});

    final withLimit = const PullRequest(
      collection: SyncCollection.entries,
      pageLimit: 250,
    ).toWireJson();
    expect(withLimit.keys.toList(), <String>['collection', 'page_limit']);
    expect(withLimit, {'collection': 'entries', 'page_limit': 250});

    final full = const PullRequest(
      collection: SyncCollection.entries,
      cursor: 'cursor-1',
      pageLimit: 250,
    ).toWireJson();
    expect(
      full,
      {
        'collection': 'entries',
        'cursor': 'cursor-1',
        'page_limit': 250,
      },
    );
  });

  test('BeginReconcile.toWireJson carries only the begin_reconcile action', () {
    expect(
      const BeginReconcile().toWireJson(),
      const {'action': 'begin_reconcile'},
    );
  });

  test(
      'CompleteReconcile.toWireJson carries action and collection_hashes with all five keys in fixed order',
      () {
    final wire = CompleteReconcile(
      collectionHashes: {
        for (final collection in SyncCollection.values) collection: 'hash',
      },
    ).toWireJson();
    expect(wire.keys.toList(), <String>['action', 'collection_hashes']);
    expect(wire['action'], 'complete_reconcile');
    expect(wire['collection_hashes'], isA<Map<String, Object?>>());
    expect(
        (wire['collection_hashes'] as Map<String, Object?>).keys.toList(),
        <String>[
          'money_sources',
          'entries',
          'categories',
          'plans',
          'budgets',
        ]);
    expect(wire, {
      'action': 'complete_reconcile',
      'collection_hashes': {
        for (final collection in SyncCollection.values)
          collection.wireName: 'hash',
      },
    });
  });

  test(
      'AcknowledgeRequest.toWireJson carries exactly collection and checkpoint',
      () {
    final wire = const AcknowledgeRequest(
      collection: SyncCollection.entries,
      checkpoint: 'checkpoint-1',
    ).toWireJson();
    expect(wire.keys.toList(), <String>['collection', 'checkpoint']);
    expect(
      wire,
      {
        'collection': 'entries',
        'checkpoint': 'checkpoint-1',
      },
    );
  });
}
