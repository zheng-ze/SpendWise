import 'package:sync/sync.dart';
import 'package:test/test.dart';

SyncEnvelope _envelope(String row) => SyncEnvelope.create(
      protocolVersion: syncProtocolVersion,
      userID: 'user-1',
      collection: SyncCollection.entries,
      rowID: row,
      versionVector: VersionVector({'device-a': 1}),
      lifecycle: SiblingLifecycle.live,
      ciphertext: 'cipher-$row',
    );

void main() {
  test('well-formed pull response exposes envelopes and next cursor', () {
    final first = _envelope('row-1');
    final second = _envelope('row-2');
    final response = PullResponse(<String, Object?>{
      'envelopes': <Object?>[first.toWireJson(), second.toWireJson()],
      'cursor': 'cursor-2',
    });

    final envelopes = response.envelopes;
    expect(envelopes.map((item) => item.rowID), ['row-1', 'row-2']);
    expect(
      envelopes.map((item) => item.toWireJson()),
      [first.toWireJson(), second.toWireJson()],
      reason: 'envelopes must round-trip through SyncEnvelope.fromWireJson.',
    );
    expect(response.cursor, 'cursor-2');
    expect(response.endOfSnapshot, isFalse);
  });

  test('zero envelopes with end_of_snapshot parses and exposes the marker', () {
    final response = PullResponse(const <String, Object?>{
      'envelopes': <Object?>[],
      'cursor': 'cursor-0',
      'end_of_snapshot': true,
    });

    expect(response.envelopes, isEmpty);
    expect(response.cursor, 'cursor-0');
    expect(response.endOfSnapshot, isTrue);
  });

  test('missing envelopes key throws a typed error', () {
    final response = PullResponse(const <String, Object?>{
      'cursor': 'cursor-1',
    });

    expect(() => response.envelopes, throwsA(isA<FormatException>()));
  });

  test('missing cursor key throws a typed error', () {
    final response = PullResponse(const <String, Object?>{
      'envelopes': <Object?>[],
    });

    expect(() => response.cursor, throwsA(isA<FormatException>()));
  });

  test('malformed envelope element throws a typed error', () {
    final response = PullResponse(<String, Object?>{
      'envelopes': <Object?>[
        _envelope('row-1').toWireJson(),
        <String, Object?>{'collection': 'entries'},
      ],
      'cursor': 'cursor-1',
    });

    expect(() => response.envelopes, throwsA(isA<FormatException>()));
  });

  test('non-boolean end_of_snapshot throws a typed error', () {
    final response = PullResponse(const <String, Object?>{
      'envelopes': <Object?>[],
      'cursor': 'cursor-1',
      'end_of_snapshot': 'yes',
    });

    expect(() => response.endOfSnapshot, throwsA(isA<FormatException>()));
  });
}
