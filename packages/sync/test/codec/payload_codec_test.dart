import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/entities.dart';

void main() {
  final codec = const PayloadCodec();

  group('entity round-trip', () {
    test('round-trips every upsert entity to an equal LedgerChange', () {
      for (final entry in allUpserts().entries) {
        final change = entry.value;
        final payload = codec.encodeChange(change);
        expect(payload, isNotEmpty, reason: '${entry.key} carries a payload');
        expect(codec.decodeChange(payload), change,
            reason: '${entry.key} must survive encode then decode');
      }
    });

    test('round-trips a card account with a statement day', () {
      final change = UpsertAccount(testAccount(statementDay: 20));
      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('round-trips a category with an actually-null parent', () {
      final change = UpsertCategory(testCategory(nullParent: true));
      expect(change.category.parentID, isNull);
      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('round-trips a plan with an actually-null end date', () {
      final change = UpsertPlan(testPlan(nullEnd: true));
      expect(change.plan.endDate, isNull);
      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });
  });

  group('tombstones', () {
    test('encodeChange for a delete is payload-free', () {
      expect(codec.encodeChange(DeleteMoneySource(uuidAccounts)), isEmpty);
      expect(codec.encodeChange(DeleteEntry(uuidEntries)), isEmpty);
    });

    test('decodeChange rejects an empty payload', () {
      expect(() => codec.decodeChange(const <int>[]),
          throwsA(isA<PayloadDecodeError>()));
    });
  });

  group('malformed and unsupported payloads', () {
    test('rejects bytes that are not canonical JSON', () {
      expect(() => codec.decodeChange(utf8.encode('not json')),
          throwsA(isA<PayloadDecodeError>()));
    });

    test('rejects a missing version field', () {
      final payload = utf8.encode(
        canonicalJson(<String, Object?>{'entity': 'account'}),
      );
      expect(() => codec.decodeChange(payload),
          throwsA(isA<PayloadDecodeError>()));
    });

    test('rejects a version other than the current one', () {
      final payload = <String, Object?>{
        'version': 99,
        'entity': 'account',
        'data': <String, Object?>{'id': uuidAccounts},
      };
      expect(
        () => codec.decodeChange(utf8.encode(canonicalJson(payload))),
        throwsA(
          isA<PayloadDecodeError>().having(
            (error) => error.message,
            'message',
            contains('Unsupported payload version'),
          ),
        ),
      );
    });

    test('rejects an unknown entity kind', () {
      final payload = <String, Object?>{
        'version': 1,
        'entity': 'mystery',
        'data': <String, Object?>{},
      };
      expect(() => codec.decodeChange(utf8.encode(canonicalJson(payload))),
          throwsA(isA<PayloadDecodeError>()));
    });

    test('rejects a wrong field type', () {
      final payload = <String, Object?>{
        'version': 1,
        'entity': 'sub_pocket',
        'data': <String, Object?>{'id': 42, 'name': 'x'},
      };
      expect(() => codec.decodeChange(utf8.encode(canonicalJson(payload))),
          throwsA(isA<PayloadDecodeError>()));
    });
  });

  group('normalized IDs', () {
    test('decodes a mixed-case row id into a lowercase entity', () {
      final payload = codec.encodeChange(
        UpsertPocket(testSubPocket(id: 'FAKE-UUID-UPPER')),
      );
      final change = codec.decodeChange(payload) as UpsertPocket;
      expect(change.pocket.id, 'fake-uuid-upper');
    });

    test('decodes a mixed-case foreign-key id into lowercase', () {
      final payload = utf8.encode(canonicalJson(<String, Object?>{
        'version': 1,
        'entity': 'entry',
        'data': <String, Object?>{
          'id': uuidEntries,
          'date': '2024-03-15T00:00:00.000Z',
          'amount': '-12.50',
          'name': 'Coffee',
          'categoryID': 'FAKE-CAT-UPPER',
          'sourceID': uuidAccounts,
          'destinationID': null,
          'includeInAnalysis': true,
          'lifecycle': 0,
          'systemKind': null,
        },
      }));
      final change = codec.decodeChange(payload) as UpsertEntry;
      expect(change.entry.categoryID, 'fake-cat-upper');
    });
  });

  group('malformed domain fields', () {
    test('an unknown systemKind code is a PayloadDecodeError', () {
      final payload = utf8.encode(canonicalJson(<String, Object?>{
        'version': 1,
        'entity': 'entry',
        'data': <String, Object?>{
          'id': uuidEntries,
          'date': '2024-03-15T00:00:00.000Z',
          'amount': '-12.50',
          'name': 'Coffee',
          'categoryID': null,
          'sourceID': uuidAccounts,
          'destinationID': null,
          'includeInAnalysis': true,
          'lifecycle': 0,
          'systemKind': 99,
        },
      }));
      expect(() => codec.decodeChange(payload),
          throwsA(isA<PayloadDecodeError>()));
    });

    test('an unparseable date is a PayloadDecodeError', () {
      final payload = utf8.encode(canonicalJson(<String, Object?>{
        'version': 1,
        'entity': 'entry',
        'data': <String, Object?>{
          'id': uuidEntries,
          'date': 'not a date',
          'amount': '-12.50',
          'name': 'Coffee',
          'categoryID': null,
          'sourceID': uuidAccounts,
          'destinationID': null,
          'includeInAnalysis': true,
          'lifecycle': 0,
          'systemKind': null,
        },
      }));
      expect(() => codec.decodeChange(payload),
          throwsA(isA<PayloadDecodeError>()));
    });

    test('an unparseable amount is a PayloadDecodeError', () {
      final payload = utf8.encode(canonicalJson(<String, Object?>{
        'version': 1,
        'entity': 'entry',
        'data': <String, Object?>{
          'id': uuidEntries,
          'date': '2024-03-15T00:00:00.000Z',
          'amount': 'not a number',
          'name': 'Coffee',
          'categoryID': null,
          'sourceID': uuidAccounts,
          'destinationID': null,
          'includeInAnalysis': true,
          'lifecycle': 0,
          'systemKind': null,
        },
      }));
      expect(() => codec.decodeChange(payload),
          throwsA(isA<PayloadDecodeError>()));
    });
  });

  group('golden fixture', () {
    test('encodeChange(account) matches the pinned canonical bytes', () {
      final payload = codec.encodeChange(UpsertAccount(testAccount()));
      expect(
        base64Url.encode(payload),
        'eyJkYXRhIjp7ImlkIjoiYWFhYWFhYWEtMDAwMC0xMTExLTIyMjItMzMzMzMzMzMzMzMzIiwiaW5jbHVkZUluTmV0V29ydGgiOnRydWUsImluY29taW5nVHJhbnNmZXJzQXNFeHBlbnNlcyI6ZmFsc2UsImxpZmVjeWNsZSI6MCwibmFtZSI6IkNoZWNraW5nIiwic3RhdGVtZW50RGF5IjpudWxsLCJzdWJQb2NrZXRJRHMiOltdLCJ0eXBlIjoxfSwiZW50aXR5IjoiYWNjb3VudCIsInZlcnNpb24iOjF9',
      );
    });
  });
}
