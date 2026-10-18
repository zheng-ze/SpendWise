import 'package:sync/sync.dart';
import 'package:test/test.dart';

// SHA-256 of the two bytes "[]" is 4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945.
const _sha256OfEmptyArrayBase64Url =
    'T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU';

void main() {
  test('sibling id ignores ciphertext and lifecycle', () {
    final vector = VersionVector({'device-a': 1});
    final id = computeSiblingID(
      userID: 'user-1',
      collection: SyncCollection.entries,
      rowID: 'row-1',
      versionVector: vector,
    );
    final live = SyncEnvelope.create(
      protocolVersion: syncProtocolVersion,
      userID: 'user-1',
      collection: SyncCollection.entries,
      rowID: 'row-1',
      versionVector: vector,
      lifecycle: SiblingLifecycle.live,
      ciphertext: 'cipher-a',
    );
    final tombstone = SyncEnvelope.create(
      protocolVersion: syncProtocolVersion,
      userID: 'user-1',
      collection: SyncCollection.entries,
      rowID: 'row-1',
      versionVector: vector,
      lifecycle: SiblingLifecycle.tombstone,
      ciphertext: 'cipher-b',
    );
    expect(live.siblingID, id);
    expect(tombstone.siblingID, id);
  });

  test('snapshot hash is independent of input ordering', () {
    SyncEnvelope envelope(String row) => SyncEnvelope.create(
          protocolVersion: syncProtocolVersion,
          userID: 'user-1',
          collection: SyncCollection.entries,
          rowID: row,
          versionVector: VersionVector({'device-a': 1}),
          lifecycle: SiblingLifecycle.live,
          ciphertext: 'cipher-$row',
        );
    final a = envelope('a');
    final b = envelope('b');
    expect(computeSnapshotHash([a, b]), computeSnapshotHash([b, a]));
  });

  test('empty snapshot hashes canonical []', () {
    expect(computeSnapshotHash(const []), _sha256OfEmptyArrayBase64Url);
  });
}
