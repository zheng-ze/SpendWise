import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/database/database_connection_native.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const _databaseName = 'native-connection-test';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spendwise-db-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
          expect(call.method, 'getApplicationDocumentsDirectory');
          return directory.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
    await directory.delete(recursive: true);
  });

  test(
    'opens a native database in the application documents directory',
    () async {
      final database = LedgerDatabase(await openConnection(_databaseName));
      final result = await database.customSelect('SELECT 1').getSingle();

      expect(result.data.values.single, 1);
      expect(
        File('${directory.path}/$_databaseName.sqlite').existsSync(),
        isTrue,
      );
      await database.close();
    },
  );
}
