import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/entities.dart';

void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
  final cipher = const SyncCipher();
  final codec = const PayloadCodec();

  SyncEngine engine({SyncStagingStore? staging}) => SyncEngine(
        userID: 'user',
        keyAccessor: () => Future<Uint8List>.value(key),
        stagingStore: staging,
      );

  Future<SyncEnvelope> buildEnvelope({
    required SyncCollection collection,
    required String rowID,
    required VersionVector version,
    required SiblingLifecycle lifecycle,
    LedgerChange? change,
  }) async {
    final normalized = normalizedID(rowID);
    final preview = SyncEnvelope(
      protocolVersion: syncProtocolVersion,
      userID: 'user',
      collection: collection,
      rowID: normalized,
      siblingID: computeSiblingID(
        userID: 'user',
        collection: collection,
        rowID: normalized,
        versionVector: version,
      ),
      versionVector: version,
      lifecycle: lifecycle,
      ciphertext: '',
    );
    final payload = lifecycle == SiblingLifecycle.tombstone
        ? const <int>[]
        : codec.encodeChange(change!);
    final framed = await cipher.encrypt(
      key: key,
      plaintext: Uint8List.fromList(payload),
      aad: preview.aadBytes(),
    );
    return SyncEnvelope(
      protocolVersion: syncProtocolVersion,
      userID: 'user',
      collection: collection,
      rowID: normalized,
      siblingID: preview.siblingID,
      versionVector: version,
      lifecycle: lifecycle,
      ciphertext: base64Url.encode(framed).replaceAll('=', ''),
    );
  }

  group('reconcile: same-row grouping', () {
    test('dominated sibling yields one conflict-free stamped change', () async {
      final earlier = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'dev': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final later = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'dev': 2}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final result = await engine().reconcile(<SyncEnvelope>[earlier, later]);
      expect(result.changes, hasLength(1));
      expect(result.stamps[SyncRowID.of(SyncCollection.entries, 'row-1')],
          VersionVector(<String, int>{'dev': 2}));
      expect(result.hasConflicts, isFalse);
    });

    test('duplicate siblings collapse to one conflict-free change', () async {
      final v1 = VersionVector(<String, int>{'dev': 3});
      final first = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: v1,
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final second = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: v1,
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final result = await engine().reconcile(<SyncEnvelope>[first, second]);
      expect(result.changes, hasLength(1));
      expect(result.stamps[SyncRowID.of(SyncCollection.entries, 'row-1')], v1);
    });

    test('mutually concurrent siblings enter staging', () async {
      final a = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'devA': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final b = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'devB': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final result = await engine().reconcile(<SyncEnvelope>[a, b]);
      expect(result.changes, isEmpty);
      expect(result.stagedConflicts, hasLength(1));
      final conflict = result.stagedConflicts.first;
      expect(conflict.collection, SyncCollection.entries);
      expect(conflict.rowID, 'row-1');
      expect(conflict.siblings, hasLength(2));
      // Staged siblings expose decoded LedgerChange content, not ciphertext.
      expect(
        conflict.siblings.map((sibling) => sibling.change),
        <LedgerChange>[
          UpsertEntry(testEntry(id: 'row-1')),
          UpsertEntry(testEntry(id: 'row-1')),
        ],
      );
    });

    test('a dominant sibling resolves a group even with a concurrent pair',
        () async {
      // devA and devB are mutually concurrent, but devA+devB dominates both.
      final concurrentA = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'devA': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final concurrentB = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'devB': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final merged = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'devA': 1, 'devB': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-1')),
      );
      final result = await engine()
          .reconcile(<SyncEnvelope>[concurrentA, merged, concurrentB]);
      expect(result.changes, hasLength(1));
      expect(result.stamps[SyncRowID.of(SyncCollection.entries, 'row-1')],
          VersionVector(<String, int>{'devA': 1, 'devB': 1}));
      expect(result.hasConflicts, isFalse);
    });

    test('a tampered tombstone envelope throws, not a silent delete', () async {
      final tombstone = await buildEnvelope(
        collection: SyncCollection.moneySources,
        rowID: 'ms-1',
        version: VersionVector(<String, int>{'dev': 1}),
        lifecycle: SiblingLifecycle.tombstone,
      );
      // A tombstone envelope still carries an AEAD-sealed (empty) payload;
      // corrupting it must fail authentication on decode.
      final tamperedCiphertext = base64Url
          .encode(_tamperBytes(_b64urlDecode(tombstone.ciphertext)))
          .replaceAll('=', '');
      final tampered = SyncEnvelope(
        protocolVersion: syncProtocolVersion,
        userID: 'user',
        collection: SyncCollection.moneySources,
        rowID: 'ms-1',
        siblingID: tombstone.siblingID,
        versionVector: VersionVector(<String, int>{'dev': 1}),
        lifecycle: SiblingLifecycle.tombstone,
        ciphertext: tamperedCiphertext,
      );
      await expectLater(
        engine().reconcile(<SyncEnvelope>[tampered]),
        throwsA(isA<SyncPayloadDecryptionError>()),
      );
    });

    test('an authenticated envelope decoding to another entity identity',
        () async {
      final misrouted = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-1',
        version: VersionVector(<String, int>{'dev': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertCategory(testCategory(id: 'row-1')),
      );
      await expectLater(
        engine().reconcile(<SyncEnvelope>[misrouted]),
        throwsA(isA<SyncPayloadIdentityError>()),
      );
    });

    test('a tombstone decode is payload-free and conflict-free', () async {
      final tombstone = await buildEnvelope(
        collection: SyncCollection.moneySources,
        rowID: 'ms-1',
        version: VersionVector(<String, int>{'dev': 1}),
        lifecycle: SiblingLifecycle.tombstone,
      );
      final result = await engine().reconcile(<SyncEnvelope>[tombstone]);
      expect(result.changes, [DeleteMoneySource('ms-1')]);
      expect(result.stamps[SyncRowID.of(SyncCollection.moneySources, 'ms-1')],
          VersionVector(<String, int>{'dev': 1}));
      expect(result.stamps[SyncRowID.of(SyncCollection.moneySources, 'ms-1')],
          VersionVector(<String, int>{'dev': 1}));
    });

    test('stages concurrent groups but leaves conflict-free rows unstaged',
        () async {
      final staging = InMemorySyncStagingStore();
      final local = SyncEngine(
        userID: 'user',
        keyAccessor: () => Future<Uint8List>.value(key),
        stagingStore: staging,
      );

      final conflictA = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-a',
        version: VersionVector(<String, int>{'devA': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-a')),
      );
      final conflictB = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-a',
        version: VersionVector(<String, int>{'devB': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-a')),
      );
      final free = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'row-b',
        version: VersionVector(<String, int>{'devC': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'row-b')),
      );

      final result = await local.reconcile(<SyncEnvelope>[
        conflictA,
        conflictB,
        free,
      ]);
      expect(result.changes, hasLength(1));
      expect(result.stagedConflicts, hasLength(1));
      expect(staging.pendingConflicts, hasLength(1));
      expect(staging.pendingConflicts.first.collection, SyncCollection.entries);
    });

    test('authentication failure throws SyncPayloadDecryptionError', () async {
      final forged = SyncEnvelope(
        protocolVersion: syncProtocolVersion,
        userID: 'user',
        collection: SyncCollection.entries,
        rowID: 'row-1',
        siblingID: computeSiblingID(
          userID: 'user',
          collection: SyncCollection.entries,
          rowID: 'row-1',
          versionVector: VersionVector(<String, int>{'dev': 1}),
        ),
        versionVector: VersionVector(<String, int>{'dev': 1}),
        lifecycle: SiblingLifecycle.live,
        ciphertext: base64Url.encode(Uint8List.fromList(
            List<int>.generate(24 + 4 + 16, (index) => index))),
      );
      await expectLater(
        engine().reconcile(<SyncEnvelope>[forged]),
        throwsA(isA<SyncPayloadDecryptionError>()),
      );
    });
  });

  group('identical UUIDs in different collections', () {
    test('keep distinct SyncRowIDs, stamps, and grouping', () async {
      final inEntries = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'shared-uuid',
        version: VersionVector(<String, int>{'devA': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'shared-uuid')),
      );
      final concurrentInEntries = await buildEnvelope(
        collection: SyncCollection.entries,
        rowID: 'shared-uuid',
        version: VersionVector(<String, int>{'devB': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertEntry(testEntry(id: 'shared-uuid')),
      );
      final inCategories = await buildEnvelope(
        collection: SyncCollection.categories,
        rowID: 'shared-uuid',
        version: VersionVector(<String, int>{'devC': 1}),
        lifecycle: SiblingLifecycle.live,
        change: UpsertCategory(testCategory(id: 'shared-uuid')),
      );
      final result = await engine().reconcile(<SyncEnvelope>[
        inEntries,
        concurrentInEntries,
        inCategories,
      ]);
      // entries group is concurrent -> staged; categories is solo -> free.
      expect(result.changes, hasLength(1));
      expect(result.stagedConflicts, hasLength(1));
      expect(result.stagedConflicts.first.collection, SyncCollection.entries);
      expect(
          result.stamps.containsKey(
              SyncRowID.of(SyncCollection.categories, 'shared-uuid')),
          isTrue);
    });
  });

  group('encode', () {
    test('produces an envelope stamped with the stored version', () async {
      final versionSource = InMemorySyncVersionSource(<SyncRowID, RowVersion>{
        SyncRowID.of(SyncCollection.entries, 'row-1'): RowVersion(
          versionVector: VersionVector(<String, int>{'dev': 7}),
          lifecycle: SiblingLifecycle.live,
        ),
      });
      final envelopes = await engine().encode(
        <LedgerChange>[UpsertEntry(testEntry(id: 'row-1'))],
        versionSource,
      );
      expect(envelopes, hasLength(1));
      final envelope = envelopes.first;
      expect(envelope.collection, SyncCollection.entries);
      expect(envelope.rowID, 'row-1');
      expect(envelope.versionVector, VersionVector(<String, int>{'dev': 7}));
      expect(envelope.lifecycle, SiblingLifecycle.live);
      expect(envelope.ciphertext, isNotEmpty);
    });

    test('encodes a delete as a payload-free tombstone envelope', () async {
      final versionSource = InMemorySyncVersionSource(<SyncRowID, RowVersion>{
        SyncRowID.of(SyncCollection.entries, 'row-1'): RowVersion.empty(),
      });
      final envelopes = await engine().encode(
        <LedgerChange>[DeleteEntry('row-1')],
        versionSource,
      );
      expect(envelopes, hasLength(1));
      expect(envelopes.first.lifecycle, SiblingLifecycle.tombstone);
    });

    test('throws for a change whose row the version source never tracked',
        () async {
      await expectLater(
        engine().encode(
          <LedgerChange>[UpsertEntry(testEntry(id: 'untracked-row'))],
          InMemorySyncVersionSource(),
        ),
        throwsA(isA<SyncUntrackedRowError>()),
      );
    });
  });

  group('scoped E2E key accessor', () {
    test('the engine fetches the key only through the accessor', () async {
      var calls = 0;
      Future<Uint8List> recording() {
        calls += 1;
        return Future<Uint8List>.value(key);
      }

      final versionSource = InMemorySyncVersionSource(<SyncRowID, RowVersion>{
        SyncRowID.of(SyncCollection.entries, 'row-1'): RowVersion.empty(),
      });
      final local = SyncEngine(userID: 'user', keyAccessor: recording);
      final envelopes = await local.encode(
        <LedgerChange>[UpsertEntry(testEntry(id: 'row-1'))],
        versionSource,
      );
      expect(calls, 1);
      expect(envelopes, hasLength(1));
    });
  });

  group('LedgerChange-to-SyncCollection mapping', () {
    test('classifies every variant to the correct collection', () {
      expect(collectionFor(UpsertAccount(testAccount())),
          SyncCollection.moneySources);
      expect(collectionFor(UpsertPocket(testSubPocket())),
          SyncCollection.moneySources);
      expect(
          collectionFor(DeleteMoneySource('x')), SyncCollection.moneySources);
      expect(collectionFor(UpsertCategory(testCategory())),
          SyncCollection.categories);
      expect(collectionFor(DeleteCategory('x')), SyncCollection.categories);
      expect(collectionFor(UpsertEntry(testEntry())), SyncCollection.entries);
      expect(collectionFor(DeleteEntry('x')), SyncCollection.entries);
      expect(collectionFor(UpsertPlan(testPlan())), SyncCollection.plans);
      expect(collectionFor(DeletePlan('x')), SyncCollection.plans);
      expect(collectionFor(UpsertBudget(testBudget())), SyncCollection.budgets);
      expect(collectionFor(DeleteBudget('x')), SyncCollection.budgets);
    });
  });
}

// Flips one byte of an AEAD frame so its tag no longer authenticates.
Uint8List _tamperBytes(Uint8List frame) {
  final corrupted = Uint8List.fromList(frame);
  corrupted[corrupted.length - 1] ^= 0xFF;
  return corrupted;
}

// Decodes an unpadded base64url string, as the cipher frames produce.
Uint8List _b64urlDecode(String value) {
  final remainder = value.length % 4;
  final padded = remainder == 0 ? value : value + '=' * (4 - remainder);
  return Uint8List.fromList(base64Url.decode(padded));
}
