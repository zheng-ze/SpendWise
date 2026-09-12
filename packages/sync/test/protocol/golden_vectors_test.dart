import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

const _siblingIdFixtures = 'test/fixtures/sibling_id_vectors.json';
const _snapshotHashFixtures = 'test/fixtures/snapshot_hash_vectors.json';

List<dynamic> _loadFixtureList(String relativePath) =>
    jsonDecode(File(relativePath).readAsStringSync()) as List<dynamic>;

/// Reproduces `canonicalJson(...)` + SHA-256 + unpadded base64url exactly as
/// `computeSiblingID`/`computeSnapshotHash` do internally, but over the raw
/// fixture map — not a domain `VersionVector`.
///
/// The golden vectors in `docs/sync-protocol.md` §5 pin the RFC 8785
/// canonicalization-and-hash mechanism itself, using illustrative device keys
/// like `deviceA` verbatim. `VersionVector` always lowercase-normalizes
/// device IDs (a separate, correct, repo-wide convention — see `CLAUDE.md`),
/// so routing a mixed-case fixture through `VersionVector` can never
/// reproduce these bytes; that is expected, not a defect. Testing the shared
/// `canonicalJson` primitive directly, at the same level the doc's vectors
/// are written at, still proves the exact mechanism `computeSiblingID`/
/// `computeSnapshotHash` depend on is correct.
String _digestOf(Object? canonicalInput) {
  final bytes = utf8.encode(canonicalJson(canonicalInput));
  return base64UrlEncode(sha256.convert(bytes).bytes).replaceAll('=', '');
}

void main() {
  final siblingVectors = _loadFixtureList(_siblingIdFixtures);
  final snapshotVectors = _loadFixtureList(_snapshotHashFixtures);

  test(
      'canonicalJson + SHA-256 + base64url reproduces the sibling-ID golden vectors',
      () {
    for (final raw in siblingVectors) {
      final input = raw['input'] as Map<String, dynamic>;
      final versionVector = (input['version_vector'] as Map<String, dynamic>)
          .map<String, Object?>(
              (key, value) => MapEntry(key, value.toString()));

      final canonicalInput = <String, Object?>{
        'user_id': input['user_id'],
        'collection': input['collection'],
        'row_id': input['row_id'],
        'version_vector': versionVector,
      };

      expect(
        _digestOf(canonicalInput),
        raw['expected_digest'],
        reason: "Sibling ID must match '${raw['description']}' verbatim.",
      );
    }
  });

  test(
      'canonicalJson + SHA-256 + base64url reproduces the collection-hash golden vectors',
      () {
    for (final raw in snapshotVectors) {
      final envelopes = raw['input']['envelopes'] as List<dynamic>;
      final canonicalArray = envelopes.map<Map<String, Object?>>((e) {
        final entry = e as Map<String, dynamic>;
        final versionVector = (entry['version_vector'] as Map<String, dynamic>)
            .map<String, Object?>(
                (key, value) => MapEntry(key, value.toString()));
        return <String, Object?>{
          'protocol_version': entry['protocol_version'],
          'user_id': entry['user_id'],
          'collection': entry['collection'],
          'row_id': entry['row_id'],
          'sibling_id': entry['sibling_id'],
          'version_vector': versionVector,
          'lifecycle': entry['lifecycle'],
          'ciphertext': entry['ciphertext'],
        };
      }).toList();

      expect(
        _digestOf(canonicalArray),
        raw['expected_digest'],
        reason: "Snapshot hash must match '${raw['description']}' verbatim.",
      );
    }
  });

  test('computeSnapshotHash of an empty collection hashes canonical []', () {
    expect(
      computeSnapshotHash(const <SyncEnvelope>[]),
      'T1PNoYwrqgwDVLtfmj7L5e0Sq02OEbqHPC8RFhICuUU',
    );
  });

  test(
      'computeSiblingID and computeSnapshotHash agree with the canonicalization primitive on a normalized (lowercase) device id',
      () {
    final vector = VersionVector({'devicea': 3});
    final directID = _digestOf(<String, Object?>{
      'user_id': '22222222-2222-2222-2222-222222222222',
      'collection': 'entries',
      'row_id': '11111111-1111-1111-1111-111111111111',
      'version_vector': vector.toWireCounters(),
    });

    final viaApi = computeSiblingID(
      userID: '22222222-2222-2222-2222-222222222222',
      collection: SyncCollection.entries,
      rowID: '11111111-1111-1111-1111-111111111111',
      versionVector: vector,
    );

    expect(viaApi, directID);
  });
}
