import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/version_vector.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// One file-backed database reopened as two `LedgerDatabase` instances is what
  /// separates a persisted id from one cached in memory. Drift's warning about
  /// opening twice is the case under test, so it is turned off here.
  Future<T> withReopenableDatabase<T>(
    Future<T> Function(LedgerDatabase Function() open) body,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    final file = File(
      '${Directory.systemTemp.createTempSync().path}/db.sqlite',
    );
    final opened = <LedgerDatabase>[];
    try {
      return await body(() {
        final db = LedgerDatabase(NativeDatabase(file));
        opened.add(db);
        return db;
      });
    } finally {
      for (final db in opened) {
        await db.close();
      }
      file.parent.deleteSync(recursive: true);
    }
  }

  test('the device id is a lowercase uuid v4', () async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await deviceID(db), matches(uuidV4));
  });

  test('the device id is stable within one store instance', () async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await deviceID(db), await deviceID(db));
  });

  test('the device id is persisted, not regenerated per read', () async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await deviceID(db);
    final stored = await db.select(db.storeMeta).getSingle();

    expect(stored.deviceId, id);
  });

  test('deviceID is stable across store instances', () async {
    await withReopenableDatabase((open) async {
      final first = await deviceID(open());
      final second = await deviceID(open());

      expect(second, first);
      expect(second, matches(uuidV4));
    });
  });

  test(
    'reopening continues the same counter rather than a fresh one',
    () async {
      await withReopenableDatabase((open) async {
        final firstDevice = await deviceID(open());
        final afterFirstRun = VersionVector.empty.bump(firstDevice);

        final secondDevice = await deviceID(open());
        final afterSecondRun = afterFirstRun.bump(secondDevice);

        expect(afterSecondRun.counters, {firstDevice: 2});
        expect(afterSecondRun.dominates(afterFirstRun), isTrue);
        expect(afterSecondRun.isConcurrent(afterFirstRun), isFalse);
      });
    },
  );

  test('an id already stored is adopted rather than replaced', () async {
    const existing = 'cccccccc-3333-4333-8333-cccccccccccc';
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.storeMeta)
        .insert(StoreMetaRow(id: 0, deviceId: existing, hasSeeded: false));

    expect(await deviceID(db), existing);
  });

  test('a stored id is normalized to lowercase on read', () async {
    const stored = 'DDDDDDDD-4444-4444-8444-DDDDDDDDDDDD';
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.storeMeta)
        .insert(StoreMetaRow(id: 0, deviceId: stored, hasSeeded: false));

    expect(await deviceID(db), stored.toLowerCase());
  });

  test('claiming the id leaves the seeding flag alone', () async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.storeMeta)
        .insert(StoreMetaRow(id: 0, deviceId: 'x', hasSeeded: true));

    await deviceID(db);

    expect((await db.select(db.storeMeta).getSingle()).hasSeeded, isTrue);
  });
}
