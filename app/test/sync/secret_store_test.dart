import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  var failStorage = false;

  setUp(() {
    values.clear();
    failStorage = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (failStorage) {
            throw PlatformException(
              code: 'test-bearer',
              message: 'opaque-test-payload',
              details: 'test-key',
            );
          }
          final arguments = call.arguments as Map<Object?, Object?>;
          final key = arguments['key']! as String;
          switch (call.method) {
            case 'write':
              values[key] = arguments['value']! as String;
              return null;
            case 'read':
              return values[key];
            case 'delete':
              values.remove(key);
              return null;
          }
          throw UnsupportedError(call.method);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a new store restores a secret written by key', () async {
    await SecureSecretStore().write('credential', 'opaque-test-payload');

    expect(await SecureSecretStore().read('credential'), 'opaque-test-payload');
  });

  test(
    'deleting the credential preserves the separately stored E2E key',
    () async {
      final store = SecureSecretStore();
      await store.write('credential', 'opaque-test-payload');
      await store.write('e2e-key', 'test-key');

      await store.delete('credential');
      await store.delete('credential');

      expect(await store.read('credential'), isNull);
      expect(await store.read('e2e-key'), 'test-key');
    },
  );

  test('storage failures redact secrets for every operation', () async {
    failStorage = true;
    final store = SecureSecretStore();
    final redacted = throwsA(
      predicate<Object>(
        (error) => error.toString() == 'Secure storage failed.',
      ),
    );

    await expectLater(store.read('test-key'), redacted);
    await expectLater(store.write('test-key', 'opaque-test-payload'), redacted);
    await expectLater(store.delete('test-key'), redacted);
    expect(store.toString(), isNot(contains('opaque-test-payload')));
  });
}
