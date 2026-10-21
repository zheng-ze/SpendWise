import 'dart:convert';

import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('independent bumps are concurrent and later bumps dominate history', () {
    final left = VersionVector.empty.bump('device-a');
    final right = VersionVector.empty.bump('device-b');
    final later = left.bump('device-a');

    expect(left.isConcurrent(right), isTrue);
    expect(later.dominates(left), isTrue);
    expect(later.dominates(right), isFalse);
  });

  test('persistence codec round-trips current vectors', () {
    final original = VersionVector({'device-a': 2, 'device-b': 7});
    final encoded = original.encode();

    expect(jsonDecode(utf8.decode(encoded)), {'device-a': 2, 'device-b': 7});
    expect(VersionVector.decode(encoded), original);
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

  test('wire counters use decimal strings', () {
    final vector = VersionVector({'device-a': 2, 'device-zero': 0});

    expect(vector.toWireCounters(), {'device-a': '2'});
    expect(
      VersionVector.fromWireCounters(vector.toWireCounters()),
      VersionVector({'device-a': 2}),
    );
  });

  test('negative counters fail decoding with a typed error', () {
    expect(
      () => VersionVector({'device-a': -1}),
      throwsA(isA<VersionVectorDecodeError>()),
    );
  });
}
