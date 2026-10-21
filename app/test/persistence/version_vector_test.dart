import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';

void main() {
  const deviceA = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
  const deviceB = 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb';

  test('bump and causality distinguish later and concurrent writes', () {
    final first = VersionVector.empty.bump(deviceA);
    final later = first.bump(deviceB).bump(deviceA);
    final concurrent = VersionVector({deviceA: 1, deviceB: 2});

    expect(later.counters, {deviceA: 2, deviceB: 1});
    expect(later.dominates(first), isTrue);
    expect(later.isConcurrent(first), isFalse);
    expect(later.isConcurrent(concurrent), isTrue);
    expect(first.counters, {deviceA: 1});
  });

  test('construction and bump normalize ids and ignore zero counters', () {
    final vector = VersionVector({deviceA.toUpperCase(): 0})
        .bump(deviceA.toUpperCase());

    expect(vector.counters, {deviceA: 1});
    expect(deviceA, matches(RegExp('[a-f]')));
  });

  test('codec reads current and Swift formats and writes current format', () {
    final vector = VersionVector({deviceA: 3, deviceB: 1});
    final current = utf8.encode('{"$deviceA":3,"$deviceB":1}');
    final swift = utf8.encode(
      '{"counters":["${deviceA.toUpperCase()}",3,"$deviceB",1]}',
    );

    expect(json.decode(utf8.decode(vector.encode())), vector.counters);
    expect(VersionVector.decode(current), vector);
    expect(VersionVector.decode(swift), vector);
    expect(VersionVector.decode(utf8.encode('')), VersionVector.empty);
  });

  test('malformed json, shape, count and utf8 raise decode errors', () {
    for (final blob in <List<int>>[
      utf8.encode('not json'),
      utf8.encode('"$deviceA"'),
      utf8.encode('{"$deviceA":1.5}'),
      [0xc3, 0x28],
    ]) {
      expect(
        () => VersionVector.decode(blob),
        throwsA(isA<VersionVectorDecodeError>()),
      );
    }
  });
}
