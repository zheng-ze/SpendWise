import 'package:sync/sync.dart';
import 'package:test/test.dart';

ReconciliationContext testContext({String? cursor}) => ReconciliationContext(
      reconciliationID: 'recon-42',
      snapshotWatermark: 'watermark-7',
      expiresAt: DateTime.utc(2026, 9, 19, 12),
      cursor: cursor,
    );

void main() {
  test('context encodes the nested reconciliation wire object', () {
    expect(testContext().toWireJson(), {
      'reconciliation_id': 'recon-42',
      'snapshot_watermark': 'watermark-7',
      'expires_at': '2026-09-19T12:00:00.000Z',
    });

    expect(testContext(cursor: 'cursor-9').toWireJson(), {
      'reconciliation_id': 'recon-42',
      'snapshot_watermark': 'watermark-7',
      'expires_at': '2026-09-19T12:00:00.000Z',
      'cursor': 'cursor-9',
    });
  });

  test('context round-trips through its wire JSON', () {
    final decoded = ReconciliationContext.fromWireJson(
      testContext(cursor: 'cursor-9').toWireJson(),
    );

    expect(decoded.reconciliationID, 'recon-42');
    expect(decoded.snapshotWatermark, 'watermark-7');
    expect(decoded.expiresAt, DateTime.utc(2026, 9, 19, 12));
    expect(decoded.cursor, 'cursor-9');
  });

  test('every context field is significant to the wire object', () {
    final baseline = testContext().toWireJson();

    ReconciliationContext altered({
      String? reconciliationID,
      String? snapshotWatermark,
      DateTime? expiresAt,
    }) =>
        ReconciliationContext(
          reconciliationID: reconciliationID ?? 'recon-42',
          snapshotWatermark: snapshotWatermark ?? 'watermark-7',
          expiresAt: expiresAt ?? DateTime.utc(2026, 9, 19, 12),
        );

    expect(
      altered(reconciliationID: 'recon-43').toWireJson(),
      isNot(baseline),
    );
    expect(
      altered(snapshotWatermark: 'watermark-8').toWireJson(),
      isNot(baseline),
    );
    expect(
      altered(expiresAt: DateTime.utc(2026, 9, 19, 13)).toWireJson(),
      isNot(baseline),
    );
    expect(testContext(cursor: 'cursor-9').toWireJson(), isNot(baseline));
  });

  test('malformed context wire JSON throws a typed error', () {
    ReconciliationContext decode(Map<String, Object?> wire) =>
        ReconciliationContext.fromWireJson(wire);

    expect(() => decode(const {}), throwsA(isA<FormatException>()));
    expect(
      () => decode(testContext().toWireJson()..remove('reconciliation_id')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => decode(testContext().toWireJson()..remove('snapshot_watermark')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => decode(testContext().toWireJson()..remove('expires_at')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => decode({
        ...testContext().toWireJson(),
        'reconciliation_id': '',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => decode({
        ...testContext().toWireJson(),
        'expires_at': 'not-a-timestamp',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => decode({...testContext().toWireJson(), 'cursor': 42}),
      throwsA(isA<FormatException>()),
    );
  });

  test('reconciliation pull carries the nested context, never a cursor', () {
    final wire = PullRequest.reconciliation(
      collection: SyncCollection.entries,
      reconciliation: testContext(cursor: 'cursor-9'),
      pageLimit: 100,
    ).toWireJson();

    expect(wire.keys.toList(), ['collection', 'reconciliation', 'page_limit']);
    expect(wire['collection'], 'entries');
    expect(wire['reconciliation'], {
      'reconciliation_id': 'recon-42',
      'snapshot_watermark': 'watermark-7',
      'expires_at': '2026-09-19T12:00:00.000Z',
      'cursor': 'cursor-9',
    });
    expect(wire.containsKey('cursor'), isFalse);
  });

  test('ordinary pull carries no reconciliation object', () {
    final wire = const PullRequest(
      collection: SyncCollection.entries,
      cursor: 'cursor-1',
    ).toWireJson();

    expect(wire.containsKey('reconciliation'), isFalse);
    expect(wire['cursor'], 'cursor-1');
  });

  test('begin-reconcile response decodes its nested context', () {
    final response = ReconcileResponse({
      'reconciliation': testContext().toWireJson(),
    });

    final context = response.reconciliationContext;
    expect(context.reconciliationID, 'recon-42');
    expect(context.snapshotWatermark, 'watermark-7');
    expect(context.expiresAt, DateTime.utc(2026, 9, 19, 12));
    expect(context.cursor, isNull);
  });

  test('begin-reconcile response without a context throws a typed error', () {
    expect(
      () => ReconcileResponse(const {}).reconciliationContext,
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ReconcileResponse(const {
        'reconciliation': <String, Object?>{},
      }).reconciliationContext,
      throwsA(isA<FormatException>()),
    );
  });

  test('mismatch carries an optional typed collection', () {
    const generic =
        SnapshotHashMismatch<ReconcileResponse>(message: 'diverged');
    expect(generic.code, 'snapshot_hash_mismatch');
    expect(generic.mismatchedCollection, isNull);

    const named = SnapshotHashMismatch<ReconcileResponse>(
      message: 'diverged',
      mismatchedCollection: SyncCollection.plans,
    );
    expect(named.code, 'snapshot_hash_mismatch');
    expect(named.mismatchedCollection, SyncCollection.plans);
  });

  test('continuation advances only the nested cursor', () {
    final advanced = testContext().withContinuation('cursor-2');

    expect(advanced.reconciliationID, 'recon-42');
    expect(advanced.snapshotWatermark, 'watermark-7');
    expect(advanced.expiresAt, DateTime.utc(2026, 9, 19, 12));
    expect(advanced.cursor, 'cursor-2');
    expect(testContext().cursor, isNull);
  });
}
