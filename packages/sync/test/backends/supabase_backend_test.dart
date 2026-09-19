import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

void main() {
  final credential = restoreTestCredential(
    deviceID: 'device-a',
    bearerToken: 'jwt',
  );

  test('begin reconcile uses proposed begin RPC', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response('{}', 200);
    });
    final backend = SupabaseSyncBackend(
      projectUrl: Uri.parse('https://project.supabase.co'),
      anonKey: 'anon',
      client: client,
    );

    final outcome = await backend.reconcile(credential, const BeginReconcile());

    expect(outcome, isA<SyncSuccess<ReconcileResponse>>());
    expect(seen.url.path, '/rest/v1/rpc/sync_begin_reconcile');
    expect(seen.headers['apikey'], 'anon');
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
    final backend = SupabaseSyncBackend(
      projectUrl: Uri.parse('https://project.supabase.co'),
      anonKey: 'anon',
      client: client,
    );

    final outcome = await backend.pull(
      credential,
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
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['collection'], 'budgets');
    expect(body.containsKey('cursor'), isFalse);
    expect(
      (body['reconciliation'] as Map<String, dynamic>)['reconciliation_id'],
      'recon-42',
    );
  });
}
