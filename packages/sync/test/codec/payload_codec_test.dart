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

  group('budget limit', () {
    Map<String, Object?> encodedBudgetData(Budget budget) {
      final decoded = jsonDecode(utf8.decode(
        codec.encodeChange(UpsertBudget(budget)),
      )) as Map<String, Object?>;
      return Map<String, Object?>.of(decoded['data']! as Map<String, Object?>);
    }

    List<int> budgetPayload(Map<String, Object?> data) => utf8.encode(
          canonicalJson(<String, Object?>{
            'version': 1,
            'entity': 'budget',
            'data': data,
          }),
        );

    Matcher decodeFailsWith(String message) => throwsA(
          isA<PayloadDecodeError>().having(
            (error) => error.message,
            'message',
            contains(message),
          ),
        );

    test('round-trips a category budget with a fractional limit', () {
      final change = UpsertBudget(Budget(
        id: uuidBudgets,
        categoryID: uuidCategories,
        limit: Decimal.parse('1234.56'),
      ));
      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('round-trips an unscoped budget', () {
      final change = UpsertBudget(Budget(
        id: uuidBudgets,
        categoryID: null,
        limit: Decimal.parse('500'),
      ));
      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('encodes the limit as its decimal string', () {
      final data = encodedBudgetData(Budget(
        id: uuidBudgets,
        categoryID: uuidCategories,
        limit: Decimal.parse('1234.56'),
      ));
      expect(data['limit'], '1234.56');
    });

    test('rejects a missing limit', () {
      final data = encodedBudgetData(testBudget())..remove('limit');
      expect(() => codec.decodeChange(budgetPayload(data)),
          decodeFailsWith('Field limit must be a string'));
    });

    test('rejects a non-string limit', () {
      final data = encodedBudgetData(testBudget())..['limit'] = 250;
      expect(() => codec.decodeChange(budgetPayload(data)),
          decodeFailsWith('Field limit must be a string'));
    });

    test('rejects a malformed decimal limit', () {
      final data = encodedBudgetData(testBudget())..['limit'] = 'twelve';
      expect(() => codec.decodeChange(budgetPayload(data)),
          decodeFailsWith('Field limit is invalid'));
    });
  });

  group('entry note', () {
    Map<String, Object?> decodedData(LedgerChange change) {
      final decoded = jsonDecode(utf8.decode(codec.encodeChange(change)));
      final json = (decoded as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      expect(json['version'], 1);
      final rawData = json['data'];
      return (rawData as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    LedgerChange decodeEntryData(Map<String, Object?> data) {
      final payload = <String, Object?>{
        'version': 1,
        'entity': 'entry',
        'data': data
      };
      return codec.decodeChange(utf8.encode(canonicalJson(payload)));
    }

    Map<String, Object?> entryData({String? note, bool includeNote = true}) {
      final data = <String, Object?>{
        'id': uuidEntries,
        'date': '2024-03-15T00:00:00.000Z',
        'amount': '-12.50',
        'name': 'Coffee',
        'categoryID': null,
        'sourceID': uuidAccounts,
        'destinationID': null,
        'includeInAnalysis': true,
        'lifecycle': 0,
        'systemKind': null,
      };
      if (includeNote) data['note'] = note;
      return data;
    }

    test('round-trips a noted active entry', () {
      final change = UpsertEntry(testEntry(note: '  Receipt kept '));

      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('round-trips a noted archived entry', () {
      final archived =
          testEntry(note: 'memo').settingLifecycle(LifecycleState.archived);
      final change = UpsertEntry(archived);

      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('round-trips a noted system entry', () {
      final system = Entry(
        id: uuidEntries,
        date: DateTime.utc(2024, 3, 15),
        amount: Decimal.parse('250'),
        name: 'Opening balance',
        sourceID: uuidAccounts,
        includeInAnalysis: false,
        systemKind: SystemEntryKind.openingBalance,
        note: 'audited',
      );

      expect(codec.decodeChange(codec.encodeChange(UpsertEntry(system))),
          UpsertEntry(system));
    });

    test('a non-null note is present in the encoded entry map', () {
      final data = decodedData(UpsertEntry(testEntry(note: 'memo')));

      expect(data['note'], 'memo');
    });

    test('a null note omits the key from the encoded entry map', () {
      final data = decodedData(UpsertEntry(testEntry()));

      expect(data.containsKey('note'), isFalse);
    });

    test('a whitespace-only note omits the key from the encoded entry map', () {
      final data = decodedData(UpsertEntry(testEntry(note: '   ')));

      expect(data.containsKey('note'), isFalse);
    });

    test('decodes a legacy entry payload without a note', () {
      final change = decodeEntryData(entryData(includeNote: false));

      expect((change as UpsertEntry).entry.note, isNull);
    });

    test('decodes an explicit null note as no note', () {
      final change = decodeEntryData(entryData());

      expect((change as UpsertEntry).entry.note, isNull);
    });

    test('decodes a surrounding-whitespace note trimmed', () {
      final change = decodeEntryData(entryData(note: '  memo '));

      expect((change as UpsertEntry).entry.note, 'memo');
    });

    test('decodes a whitespace-only note as no note', () {
      final change = decodeEntryData(entryData(note: '   '));

      expect((change as UpsertEntry).entry.note, isNull);
    });

    test('rejects a non-string note value', () {
      for (final bad in <Object?>[42, true, <Object?>[], <String, Object?>{}]) {
        expect(
          () => decodeEntryData(entryData(note: null)..['note'] = bad),
          throwsA(isA<PayloadDecodeError>()),
          reason: '$bad',
        );
      }
    });

    test('ignores an unknown key on an entry payload', () {
      final data = entryData(note: 'memo')..['futureField'] = 'future';

      final change = decodeEntryData(data);

      expect((change as UpsertEntry).entry.note, 'memo');
    });
  });

  group('template note', () {
    Map<String, Object?> decodedTemplate(LedgerChange change) {
      final decoded = jsonDecode(utf8.decode(codec.encodeChange(change)));
      final json = (decoded as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      expect(json['version'], 1);
      final rawData = json['data'];
      final data = (rawData as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final rawTemplate = data['template'];
      return (rawTemplate as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    LedgerChange decodePlanData(Map<String, Object?> data) {
      final payload = <String, Object?>{
        'version': 1,
        'entity': 'plan',
        'data': data
      };
      return codec.decodeChange(utf8.encode(canonicalJson(payload)));
    }

    Map<String, Object?> planData({String? note, bool includeNote = true}) {
      final template = <String, Object?>{
        'amount': '50.00',
        'name': 'Rent',
        'categoryID': null,
        'sourceID': uuidAccounts,
        'destinationID': null,
        'includeInAnalysis': true,
      };
      if (includeNote) template['note'] = note;
      return <String, Object?>{
        'id': uuidPlans,
        'template': template,
        'frequency': 2,
        'anchor': '2024-01-01T00:00:00.000Z',
        'endDate': '2024-12-31T00:00:00.000Z',
        'lastResolvedDate': '2024-06-01T00:00:00.000Z',
      };
    }

    Map<String, Object?> frozenTemplateData(EntryTemplate template) =>
        <String, Object?>{
          'amount': template.amount.toString(),
          'name': template.name,
          'categoryID': template.categoryID,
          'sourceID': template.sourceID,
          'destinationID': template.destinationID,
          'includeInAnalysis': template.includeInAnalysis,
        };

    EntryTemplate frozenDecodeTemplate(Map<String, Object?> raw) =>
        EntryTemplate(
          amount: Decimal.parse(raw['amount'] as String),
          name: raw['name'] as String,
          categoryID: raw['categoryID'] as String?,
          sourceID: raw['sourceID'] as String,
          destinationID: raw['destinationID'] as String?,
          includeInAnalysis: raw['includeInAnalysis'] as bool,
        );

    test('round-trips a noted plan template', () {
      final change =
          UpsertPlan(testPlan(template: testTemplate(note: '  memo ')));

      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('round-trips a noted transfer plan template', () {
      final template = EntryTemplate(
        amount: Decimal.parse('-25.00'),
        name: 'Move',
        sourceID: uuidAccounts,
        destinationID: uuidPockets,
        note: '  memo ',
      );

      expect(
        codec.decodeChange(
          codec.encodeChange(UpsertPlan(testPlan(template: template))),
        ),
        UpsertPlan(testPlan(template: template)),
      );
    });

    test('a non-null note is nested under template, not the plan root', () {
      final decoded = jsonDecode(
        utf8.decode(
          codec.encodeChange(
              UpsertPlan(testPlan(template: testTemplate(note: 'memo')))),
        ),
      );
      final json = (decoded as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final data = (json['data'] as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );

      expect(data.containsKey('note'), isFalse);
      final template =
          (data['template'] as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      expect(template['note'], 'memo');
    });

    test('a null note omits the key from the encoded template map', () {
      expect(
          decodedTemplate(UpsertPlan(testPlan())).containsKey('note'), isFalse);
    });

    test('a whitespace-only note omits the key from the template map', () {
      final change = UpsertPlan(testPlan(template: testTemplate(note: '   ')));

      expect(decodedTemplate(change).containsKey('note'), isFalse);
      expect(codec.decodeChange(codec.encodeChange(change)), change);
    });

    test('decodes a legacy template payload without a note', () {
      final change = decodePlanData(planData(includeNote: false));

      expect((change as UpsertPlan).plan.template.note, isNull);
    });

    test('decodes an explicit null template note as no note', () {
      final change = decodePlanData(planData());

      expect((change as UpsertPlan).plan.template.note, isNull);
    });

    test('decodes a surrounding-whitespace template note trimmed', () {
      final change = decodePlanData(planData(note: '  memo '));

      expect((change as UpsertPlan).plan.template.note, 'memo');
    });

    test('decodes a whitespace-only template note as no note', () {
      final change = decodePlanData(planData(note: '   '));

      expect((change as UpsertPlan).plan.template.note, isNull);
    });

    test('rejects a non-string template note value', () {
      for (final bad in <Object?>[42, true, <Object?>[], <String, Object?>{}]) {
        final data = planData(note: null);
        (data['template'] as Map<String, Object?>)['note'] = bad;
        expect(
          () => decodePlanData(data),
          throwsA(isA<PayloadDecodeError>()),
          reason: '$bad',
        );
      }
    });

    test('a null-note template keeps the frozen pre-change bytes', () {
      final template = testTemplate();
      final frozen = utf8.encode(
        canonicalJson(<String, Object?>{
          'version': 1,
          'entity': 'plan',
          'data': <String, Object?>{
            'id': uuidPlans,
            'template': frozenTemplateData(template),
            'frequency': 2,
            'anchor': '2024-01-01T00:00:00.000Z',
            'endDate': '2024-12-31T00:00:00.000Z',
            'lastResolvedDate': '2024-06-01T00:00:00.000Z',
          },
        }),
      );

      expect(codec.encodeChange(UpsertPlan(testPlan())), frozen);
    });

    test('a frozen old decoder ignores a new note key and drops it on save',
        () {
      final template = decodedTemplate(
        UpsertPlan(testPlan(template: testTemplate(note: 'memo'))),
      );

      final recovered = frozenDecodeTemplate(template);

      expect(recovered.note, isNull);
      expect(frozenTemplateData(recovered).containsKey('note'), isFalse);
    });

    test('payload, envelope and operation versions stay 1, 1 and 2', () {
      final decoded = jsonDecode(
        utf8.decode(
          codec.encodeChange(
              UpsertPlan(testPlan(template: testTemplate(note: 'memo')))),
        ),
      );
      final json = (decoded as Map<Object?, Object?>).map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );

      expect(json['version'], 1);
      expect(syncProtocolVersion, 1);
      expect(syncOperationMajor, 2);
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

    test('decodes a mixed-case budget category id into lowercase', () {
      // Budget does not self-normalize categoryID, so this stays green only if
      // the codec normalizes it on decode rather than the domain entity.
      final encoded = codec.encodeChange(UpsertBudget(testBudget()));
      final decoded = jsonDecode(utf8.decode(encoded));
      if (decoded is! Map<Object?, Object?>) {
        fail('Encoded payload must decode to a JSON object.');
      }
      final json = decoded.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final rawData = json['data'];
      if (rawData is! Map<Object?, Object?>) {
        fail('Encoded payload data must be a JSON object.');
      }
      final data = rawData.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      data['categoryID'] = 'FAKE-CAT-UPPER';
      json['data'] = data;
      final change =
          codec.decodeChange(utf8.encode(canonicalJson(json))) as UpsertBudget;
      expect(change.budget.categoryID, 'fake-cat-upper');
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
