import 'package:sync/sync.dart';
import 'package:test/test.dart';

Map<String, Object?> _row({
  required String rowID,
  required String collection,
  required Object? siblingID,
  required Object? status,
  Map<String, Object?>? versionVector,
}) =>
    <String, Object?>{
      'row_id': rowID,
      'collection': collection,
      'sibling_id': siblingID,
      'status': status,
      if (versionVector != null) 'version_vector': versionVector,
    };

void main() {
  test('decodes applied, already_present and rejected rows keyed by SyncRowID',
      () {
    final response = PushResponse(<String, Object?>{
      'rows': <Object?>[
        _row(
          rowID: 'row-1',
          collection: 'entries',
          siblingID: 'sibling-applied',
          status: 'applied',
          versionVector: <String, Object?>{'device-a': '2'},
        ),
        _row(
          rowID: 'row-2',
          collection: 'entries',
          siblingID: 'sibling-present',
          status: 'already_present',
          versionVector: <String, Object?>{'device-a': '1'},
        ),
        _row(
          rowID: 'row-3',
          collection: 'categories',
          siblingID: 'sibling-rejected',
          status: 'rejected',
        ),
      ],
    });

    final outcomes = response.rowOutcomes;

    expect(
      outcomes.keys,
      unorderedEquals(<SyncRowID>[
        SyncRowID.of(SyncCollection.entries, 'row-1'),
        SyncRowID.of(SyncCollection.entries, 'row-2'),
        SyncRowID.of(SyncCollection.categories, 'row-3'),
      ]),
    );

    final applied = outcomes[SyncRowID.of(SyncCollection.entries, 'row-1')];
    expect(applied, isA<PushApplied>());
    if (applied == null) fail('missing outcome for row-1');
    switch (applied) {
      case PushApplied(
          siblingID: final siblingID,
          resultingFrontier: final frontier
        ):
        expect(siblingID, 'sibling-applied');
        expect(frontier, VersionVector({'device-a': 2}));
      case PushAlreadyPresent():
        fail('expected PushApplied for row-1');
      case PushRejected():
        fail('expected PushApplied for row-1');
    }

    final present = outcomes[SyncRowID.of(SyncCollection.entries, 'row-2')];
    expect(present, isA<PushAlreadyPresent>());
    if (present == null) fail('missing outcome for row-2');
    switch (present) {
      case PushAlreadyPresent(
          siblingID: final siblingID,
          resultingFrontier: final frontier
        ):
        expect(siblingID, 'sibling-present');
        expect(frontier, VersionVector({'device-a': 1}));
      case PushApplied():
        fail('expected PushAlreadyPresent for row-2');
      case PushRejected():
        fail('expected PushAlreadyPresent for row-2');
    }
    final rejected = outcomes[SyncRowID.of(SyncCollection.categories, 'row-3')];
    expect(rejected, isA<PushRejected>());
    if (rejected == null) fail('missing outcome for row-3');
    switch (rejected) {
      case PushRejected(siblingID: final siblingID):
        expect(siblingID, 'sibling-rejected');
      case PushApplied():
        fail('expected PushRejected for row-3');
      case PushAlreadyPresent():
        fail('expected PushRejected for row-3');
    }
  });

  test('missing rows key throws a typed error', () {
    final response = PushResponse(const <String, Object?>{});

    expect(() => response.rowOutcomes, throwsA(isA<FormatException>()));
  });

  test('missing status throws a typed error, never a raw cast error', () {
    final response = PushResponse(<String, Object?>{
      'rows': <Object?>[
        <String, Object?>{
          'row_id': 'row-1',
          'collection': 'entries',
          'sibling_id': 'sibling-1',
        },
      ],
    });

    expect(() => response.rowOutcomes, throwsA(isA<FormatException>()));
  });

  test('unrecognized status string throws a typed error', () {
    final response = PushResponse(<String, Object?>{
      'rows': <Object?>[
        _row(
          rowID: 'row-1',
          collection: 'entries',
          siblingID: 'sibling-1',
          status: 'maybe_applied',
          versionVector: <String, Object?>{'device-a': '1'},
        ),
      ],
    });

    expect(() => response.rowOutcomes, throwsA(isA<FormatException>()));
  });

  test('missing version_vector on an applied entry throws a typed error', () {
    final response = PushResponse(<String, Object?>{
      'rows': <Object?>[
        _row(
          rowID: 'row-1',
          collection: 'entries',
          siblingID: 'sibling-1',
          status: 'applied',
        ),
      ],
    });

    expect(() => response.rowOutcomes, throwsA(isA<FormatException>()));
  });

  test(
      'missing version_vector on an already_present entry throws a typed error',
      () {
    final response = PushResponse(<String, Object?>{
      'rows': <Object?>[
        _row(
          rowID: 'row-1',
          collection: 'entries',
          siblingID: 'sibling-1',
          status: 'already_present',
        ),
      ],
    });

    expect(() => response.rowOutcomes, throwsA(isA<FormatException>()));
  });

  test('missing sibling_id throws a typed error', () {
    final response = PushResponse(<String, Object?>{
      'rows': <Object?>[
        <String, Object?>{
          'row_id': 'row-1',
          'collection': 'entries',
          'status': 'rejected',
        },
      ],
    });

    expect(() => response.rowOutcomes, throwsA(isA<FormatException>()));
  });

  test('non-string sibling_id throws a typed error, never a raw cast error',
      () {
    final response = PushResponse(<String, Object?>{
      'rows': <Object?>[
        <String, Object?>{
          'row_id': 'row-1',
          'collection': 'entries',
          'sibling_id': 42,
          'status': 'rejected',
        },
      ],
    });

    expect(() => response.rowOutcomes, throwsA(isA<FormatException>()));
  });
}
