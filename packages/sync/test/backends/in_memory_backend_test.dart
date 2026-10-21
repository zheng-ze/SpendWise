import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

void main() {
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
}
