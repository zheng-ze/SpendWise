import 'dart:convert';

import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('dominance is reflexive and concurrency excludes equality', () {
    final vector = VersionVector({'device-a': 1});

    expect(vector.dominates(vector), isTrue);
    expect(vector.isConcurrent(vector), isFalse);
  });

  test('bump produces causal dominance', () {
    final base = VersionVector({'device-a': 1});
    final next = base.bump('device-a');

    expect(next.dominates(base), isTrue);
    expect(base.dominates(next), isFalse);
  });

  test('independent bumps are concurrent', () {
    final base = VersionVector.empty;
    final left = base.bump('device-a');
    final right = base.bump('device-b');

    expect(left.isConcurrent(right), isTrue);
  });

  test('zero counters are filtered and empty vectors use the singleton', () {
    expect(VersionVector({'device-a': 0}), same(VersionVector.empty));
  });

  test('counters exposes the normalized counters', () {
    final vector = VersionVector({'device-a': 1});

    expect(vector.counters, {'device-a': 1});
  });

  test('counters cannot be mutated through the exposed map', () {
    final vector = VersionVector({'device-a': 1});

    expect(
      () => vector.counters['device-b'] = 9,
      throwsUnsupportedError,
    );
  });

  test('negative counters use VersionVectorDecodeError', () {
    expect(
      () => VersionVector({'device-a': -1}),
      throwsA(isA<VersionVectorDecodeError>()),
    );
  });

  test('persistence codec is UTF-8 bytes and round trips object form', () {
    final original = VersionVector({'device-a': 2, 'device-b': 7});
    final encoded = original.encode();

    expect(encoded, isA<List<int>>());
    expect(jsonDecode(utf8.decode(encoded)), {'device-a': 2, 'device-b': 7});
    expect(VersionVector.decode(encoded), original);
  });

  test('empty persistence blob decodes to VersionVector.empty', () {
    expect(VersionVector.decode(const <int>[]), same(VersionVector.empty));
  });

  test('legacy Swift alternating-array persistence form still decodes', () {
    final encoded = utf8.encode(
      jsonEncode(<Object>['device-a', 2, 'device-b', 7]),
    );

    expect(
      VersionVector.decode(encoded),
      VersionVector({'device-a': 2, 'device-b': 7}),
    );
  });

  test("decodes Swift's wrapped flat alternating-array form", () {
    final encoded = utf8.encode(
      jsonEncode(<String, Object>{
        'counters': <Object>['DEVICE-A', 3, 'DEVICE-B', 1],
      }),
    );

    expect(
      VersionVector.decode(encoded),
      VersionVector({'device-a': 3, 'device-b': 1}),
    );
  });

  test('decodes a wrapped object form', () {
    final encoded = utf8.encode(
      jsonEncode(<String, Object>{
        'counters': <String, int>{'device-a': 3},
      }),
    );

    expect(VersionVector.decode(encoded), VersionVector({'device-a': 3}));
  });

  test('decodes wrapped empty array as the empty vector', () {
    final encoded = utf8.encode(
      jsonEncode(<String, Object>{'counters': <Object>[]}),
    );

    expect(VersionVector.decode(encoded), same(VersionVector.empty));
  });

  test('decodes wrapped empty object as the empty vector', () {
    final encoded = utf8.encode(
      jsonEncode(<String, Object>{'counters': <String, int>{}}),
    );

    expect(VersionVector.decode(encoded), same(VersionVector.empty));
  });

  test('wire counters are decimal strings and round trip independently', () {
    final vector = VersionVector({'device-a': 2, 'device-zero': 0});

    expect(vector.toWireCounters(), {'device-a': '2'});
    expect(
      VersionVector.fromWireCounters(vector.toWireCounters()),
      VersionVector({'device-a': 2}),
    );
  });
}
