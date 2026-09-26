import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

void main() {
  test('fake records backend operations', () async {
    final backend = InMemorySyncBackend();
    final credential = restoreTestCredential(
      deviceID: 'device-a',
      bearerToken: 'token',
    );

    await backend.pull(
      credential,
      const PullRequest(collection: SyncCollection.entries),
    );
    await backend.acknowledge(
      credential,
      const AcknowledgeRequest(
        collection: SyncCollection.entries,
        checkpoint: 'checkpoint-1',
      ),
    );

    expect(backend.calls, ['pull', 'acknowledge']);
  });

  test('an unprovisioned device falls through to the reconcile handler',
      () async {
    final backend = InMemorySyncBackend(
      onReconcile: (credential, request) async =>
          SyncSuccess(ReconcileResponse(const {'from': 'handler'})),
    );
    final credential = restoreTestCredential(
      deviceID: 'device-a',
      bearerToken: 'token',
    );

    final outcome = await backend.reconcile(credential, const BeginReconcile());

    expect(
      (outcome as SyncSuccess<ReconcileResponse>).value.wire['from'],
      'handler',
    );
  });

  test('an unprovisioned device with no handler gets an empty success',
      () async {
    final backend = InMemorySyncBackend();
    final credential = restoreTestCredential(
      deviceID: 'device-a',
      bearerToken: 'token',
    );

    final outcome = await backend.reconcile(credential, const BeginReconcile());

    expect(outcome, isA<SyncSuccess<ReconcileResponse>>());
  });
}
