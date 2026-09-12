import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  final credential = DeviceCredential.testing(
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
}
