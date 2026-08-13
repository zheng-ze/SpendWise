import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/version_vector.dart';

void main() {
  const deviceA = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
  const deviceB = 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb';

  group('vector algebra', () {
    test('bump increments per device', () {
      const empty = VersionVector.empty;

      final onceA = empty.bump(deviceA);
      expect(onceA.counters, {deviceA: 1});

      final twiceA = onceA.bump(deviceA);
      expect(twiceA.counters, {deviceA: 2});

      final alsoB = twiceA.bump(deviceB);
      expect(alsoB.counters, {deviceA: 2, deviceB: 1});
    });

    test('bump normalizes the device id to lowercase', () {
      final bumped = VersionVector.empty.bump(deviceA.toUpperCase());

      expect(deviceA, matches(RegExp('[a-f]')));
      expect(bumped.counters, {deviceA: 1});
    });

    test('bump leaves the receiver unchanged', () {
      final original = VersionVector.empty.bump(deviceA);
      original.bump(deviceA);

      expect(original.counters, {deviceA: 1});
    });

    test('dominates when every component is greater or equal', () {
      final lesser = VersionVector({deviceA: 1, deviceB: 1});
      final greater = VersionVector({deviceA: 2, deviceB: 1});

      expect(greater.dominates(lesser), isTrue);
      expect(lesser.dominates(greater), isFalse);
    });

    test('dominates treats a missing component as zero', () {
      final withB = VersionVector({deviceA: 1, deviceB: 1});
      final withoutB = VersionVector({deviceA: 1});

      expect(withB.dominates(withoutB), isTrue);
      expect(withoutB.dominates(withB), isFalse);
    });

    test('an equal vector dominates', () {
      final one = VersionVector({deviceA: 3});
      final other = VersionVector({deviceA: 3});

      expect(one.dominates(other), isTrue);
      expect(other.dominates(one), isTrue);
    });

    test('concurrent when neither dominates', () {
      final aheadOnA = VersionVector({deviceA: 2, deviceB: 1});
      final aheadOnB = VersionVector({deviceA: 1, deviceB: 2});

      expect(aheadOnA.dominates(aheadOnB), isFalse);
      expect(aheadOnB.dominates(aheadOnA), isFalse);
      expect(aheadOnA.isConcurrent(aheadOnB), isTrue);
      expect(aheadOnB.isConcurrent(aheadOnA), isTrue);
    });

    test('a causal chain is not concurrent', () {
      final first = VersionVector.empty.bump(deviceA);
      final second = first.bump(deviceB);
      final third = second.bump(deviceA);

      expect(first.isConcurrent(second), isFalse);
      expect(second.isConcurrent(third), isFalse);
      expect(first.isConcurrent(third), isFalse);
      expect(third.dominates(first), isTrue);
    });

    test('two empty vectors are neither concurrent nor distinguishable', () {
      expect(VersionVector.empty.isConcurrent(VersionVector.empty), isFalse);
    });

    test('equal vectors are equal regardless of construction order', () {
      final built = VersionVector.empty.bump(deviceA).bump(deviceB);
      final literal = VersionVector({deviceB: 1, deviceA: 1});

      expect(built, literal);
      expect(built.hashCode, literal.hashCode);
    });

    test('a zero count is dropped so it cannot masquerade as history', () {
      expect(VersionVector({deviceA: 0}), VersionVector.empty);
    });

    test('the constructor normalizes device ids', () {
      final vector = VersionVector({deviceA.toUpperCase(): 4});

      expect(deviceA, matches(RegExp('[a-f]')));
      expect(vector.counters, {deviceA: 4});
    });

    test('counters cannot be mutated through the exposed map', () {
      final vector = VersionVector({deviceA: 1});

      expect(() => vector.counters[deviceB] = 9, throwsUnsupportedError);
    });
  });

  group('codec', () {
    test('encodes as a utf-8 json object of device id to count', () {
      final encoded = VersionVector({deviceA: 2}).encode();

      expect(json.decode(utf8.decode(encoded)), {deviceA: 2});
    });

    test('encodes the empty vector as an empty object', () {
      expect(utf8.decode(VersionVector.empty.encode()), '{}');
    });

    test('round-trips through the object form', () {
      final vector = VersionVector({deviceA: 3, deviceB: 7});

      expect(VersionVector.decode(vector.encode()), vector);
    });

    test('decodes the object form written by this version', () {
      final blob = utf8.encode('{"$deviceA":3,"$deviceB":1}');

      expect(VersionVector.decode(blob).counters, {deviceA: 3, deviceB: 1});
    });

    /// Swift encoded the struct rather than the map, so the flat alternating
    /// array arrives wrapped under `counters` with uppercase uuids.
    test("decodes swift's wrapped flat alternating array form", () {
      final blob = utf8.encode(
        '{"counters":["${deviceA.toUpperCase()}",3,'
        '"${deviceB.toUpperCase()}",1]}',
      );

      expect(VersionVector.decode(blob).counters, {deviceA: 3, deviceB: 1});
    });

    test('decodes a bare flat alternating array', () {
      final blob = utf8.encode('["$deviceA",3,"$deviceB",1]');

      expect(VersionVector.decode(blob).counters, {deviceA: 3, deviceB: 1});
    });

    test('decodes a wrapped object form', () {
      final blob = utf8.encode('{"counters":{"$deviceA":3}}');

      expect(VersionVector.decode(blob).counters, {deviceA: 3});
    });

    test('decodes every empty encoding as the empty vector', () {
      for (final form in ['{}', '[]', '{"counters":[]}', '{"counters":{}}']) {
        expect(
          VersionVector.decode(utf8.encode(form)),
          VersionVector.empty,
          reason: form,
        );
      }
    });

    test('decoding normalizes device ids to lowercase', () {
      final object = utf8.encode('{"${deviceA.toUpperCase()}":2}');
      final flat = utf8.encode('["${deviceA.toUpperCase()}",2]');

      expect(deviceA, matches(RegExp('[a-f]')));
      expect(VersionVector.decode(object).counters, {deviceA: 2});
      expect(VersionVector.decode(flat).counters, {deviceA: 2});
    });

    test('an empty blob decodes as the empty vector', () {
      expect(VersionVector.decode(utf8.encode('')), VersionVector.empty);
    });

    test('a corrupt blob raises rather than emptying the vector', () {
      expect(
        () => VersionVector.decode(utf8.encode('not json at all')),
        throwsA(isA<VersionVectorDecodeError>()),
      );
    });

    test('every malformed shape raises rather than emptying the vector', () {
      final malformed = {
        'truncated json': '{"$deviceA":',
        'a bare number': '42',
        'a bare string': '"$deviceA"',
        'json null': 'null',
        'a count that is not a number': '{"$deviceA":"three"}',
        'a fractional count': '{"$deviceA":1.5}',
        'a negative count': '{"$deviceA":-1}',
        'an odd-length flat array': '["$deviceA",3,"$deviceB"]',
        'a flat array with a non-string id': '[7,3]',
        'a flat array with a non-integer count': '["$deviceA","three"]',
        'a nested object': '{"$deviceA":{"count":3}}',
      };

      for (final entry in malformed.entries) {
        expect(
          () => VersionVector.decode(utf8.encode(entry.value)),
          throwsA(isA<VersionVectorDecodeError>()),
          reason: entry.key,
        );
      }
    });

    test('invalid utf-8 raises rather than emptying the vector', () {
      expect(
        () => VersionVector.decode([0xc3, 0x28]),
        throwsA(isA<VersionVectorDecodeError>()),
      );
    });
  });
}
