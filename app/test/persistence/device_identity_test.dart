import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';
import 'package:spendwise/persistence/store/device_identity.dart';

void main() {
  test(
    'device identity is a persisted lowercase uuid v4 across reopen',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final directory = Directory.systemTemp.createTempSync();
      final file = File('${directory.path}/db.sqlite');
      final firstDatabase = LedgerDatabase(NativeDatabase(file));
      final firstID = await deviceID(firstDatabase);
      await firstDatabase.close();

      final secondDatabase = LedgerDatabase(NativeDatabase(file));
      addTearDown(() async {
        await secondDatabase.close();
        directory.deleteSync(recursive: true);
      });

      final secondID = await deviceID(secondDatabase);

      expect(secondID, firstID);
      expect(
        secondID,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );

  test(
    'claiming an existing identity normalizes it without changing seeding',
    () async {
      final db = LedgerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.storeMeta)
          .insert(
            const StoreMetaRow(
              id: 0,
              deviceId: 'DDDDDDDD-4444-4444-8444-DDDDDDDDDDDD',
              hasSeeded: true,
            ),
          );

      expect(await deviceID(db), 'dddddddd-4444-4444-8444-dddddddddddd');
      expect((await db.select(db.storeMeta).getSingle()).hasSeeded, isTrue);
    },
  );
}
