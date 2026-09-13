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
}
