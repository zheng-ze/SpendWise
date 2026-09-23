import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';

import 'in_memory_secret_store.dart';

String encodeKey(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

void main() {
  late InMemorySecretStore secrets;
  late SyncE2EKeyProvider provider;

  setUp(() {
    secrets = InMemorySecretStore();
    provider = SyncE2EKeyProvider(secretStore: secrets);
  });

  test('a well-formed 32-byte key round-trips through the accessor', () async {
    final expected = Uint8List.fromList(
      List<int>.generate(32, (index) => index),
    );
    await secrets.write(syncE2EKeySecretKey, encodeKey(expected));

    final actual = await provider.accessor();

    expect(actual, expected);
  });

  test('accessing the closure reads lazily on each invocation', () async {
    final first = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final second = Uint8List.fromList(
      List<int>.generate(32, (index) => 31 - index),
    );
    await secrets.write(syncE2EKeySecretKey, encodeKey(first));

    final accessor = provider.accessor;
    expect(secrets.reads, isEmpty);

    expect(await accessor(), first);
    await secrets.write(syncE2EKeySecretKey, encodeKey(second));
    expect(await accessor(), second);
    expect(secrets.reads, [syncE2EKeySecretKey, syncE2EKeySecretKey]);
  });

  test('an absent key fails with the absent reason', () async {
    await expectLater(
      provider.accessor(),
      throwsA(
        isA<SyncE2EKeyUnavailableException>()
            .having(
              (error) => error.reason,
              'reason',
              SyncE2EKeyUnavailableReason.absent,
            )
            .having(
              (error) => error.toString(),
              'message',
              'Sync E2E key unavailable (absent).',
            ),
      ),
    );
  });

  test('an undecodable value fails with the malformed reason', () async {
    const malformed = '!!!-not-valid-base64-!!!';
    await secrets.write(syncE2EKeySecretKey, malformed);

    await expectLater(
      provider.accessor(),
      throwsA(
        isA<SyncE2EKeyUnavailableException>()
            .having(
              (error) => error.reason,
              'reason',
              SyncE2EKeyUnavailableReason.malformed,
            )
            .having(
              (error) => error.toString(),
              'message',
              'Sync E2E key unavailable (malformed).',
            ),
      ),
    );
  });

  test('a value decoding to the wrong length fails', () async {
    final short = Uint8List.fromList(List<int>.generate(16, (index) => index));
    final raw = encodeKey(short);
    await secrets.write(syncE2EKeySecretKey, raw);

    await expectLater(
      provider.accessor(),
      throwsA(
        isA<SyncE2EKeyUnavailableException>()
            .having(
              (error) => error.reason,
              'reason',
              SyncE2EKeyUnavailableReason.wrongLength,
            )
            .having(
              (error) => error.toString(),
              'message',
              'Sync E2E key unavailable (wrongLength).',
            ),
      ),
    );
  });

  test(
    'a storage failure surfaces as storageFailed, not the raw error',
    () async {
      secrets.readFailure = const SecretStoreException();

      await expectLater(
        provider.accessor(),
        throwsA(
          isA<SyncE2EKeyUnavailableException>()
              .having(
                (error) => error.reason,
                'reason',
                SyncE2EKeyUnavailableReason.storageFailed,
              )
              .having(
                (error) => error.toString(),
                'message',
                'Sync E2E key unavailable (storageFailed).',
              ),
        ),
      );
    },
  );

  test('failure messages never expose key bytes or stored values', () async {
    const malformed = '!!!-sensitive-malformed-value-!!!';
    final short = Uint8List.fromList(List<int>.generate(16, (index) => index));
    final wrongLengthRaw = encodeKey(short);

    Future<String> messageFrom(Future<void> Function() action) async {
      try {
        await action();
      } on SyncE2EKeyUnavailableException catch (error) {
        return error.toString();
      }
      throw StateError('Expected the E2E key read to fail.');
    }

    final absentMessage = await messageFrom(provider.accessor);
    await secrets.write(syncE2EKeySecretKey, malformed);
    final malformedMessage = await messageFrom(provider.accessor);
    await secrets.write(syncE2EKeySecretKey, wrongLengthRaw);
    final wrongLengthMessage = await messageFrom(provider.accessor);
    secrets.readFailure = const SecretStoreException();
    final storageMessage = await messageFrom(provider.accessor);

    for (final message in [
      absentMessage,
      malformedMessage,
      wrongLengthMessage,
      storageMessage,
    ]) {
      expect(message, isNot(contains(malformed)));
      expect(message, isNot(contains(wrongLengthRaw)));
      expect(message, isNot(contains('sensitive')));
    }
  });

  test('reading the E2E key never touches the credential key', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    await secrets.write(syncE2EKeySecretKey, encodeKey(key));
    await secrets.write(syncCredentialSecretKey, 'credential-payload');

    expect(await provider.accessor(), key);
    await secrets.delete(syncE2EKeySecretKey);
    await expectLater(
      provider.accessor(),
      throwsA(isA<SyncE2EKeyUnavailableException>()),
    );
    await secrets.write(syncE2EKeySecretKey, '!!!-not-base64-!!!');
    await expectLater(
      provider.accessor(),
      throwsA(isA<SyncE2EKeyUnavailableException>()),
    );
    await secrets.write(
      syncE2EKeySecretKey,
      encodeKey(Uint8List.fromList(List<int>.filled(8, 1))),
    );
    await expectLater(
      provider.accessor(),
      throwsA(isA<SyncE2EKeyUnavailableException>()),
    );
    secrets.readFailure = const SecretStoreException();
    await expectLater(
      provider.accessor(),
      throwsA(isA<SyncE2EKeyUnavailableException>()),
    );

    expect(secrets.reads, isNotEmpty);
    expect(secrets.reads, isNot(contains(syncCredentialSecretKey)));
    expect(secrets.reads, everyElement(syncE2EKeySecretKey));
    secrets.readFailure = null;
    expect(await secrets.read(syncCredentialSecretKey), 'credential-payload');
  });

  group('decodeAndValidateSyncE2EKey', () {
    test('a valid 32-byte key decodes to the original bytes', () {
      final expected = Uint8List.fromList(
        List<int>.generate(32, (index) => index),
      );

      expect(decodeAndValidateSyncE2EKey(encodeKey(expected)), expected);
    });

    test('malformed input fails with the malformed reason', () {
      expect(
        () => decodeAndValidateSyncE2EKey('!!!-not-valid-base64-!!!'),
        throwsA(
          isA<SyncE2EKeyUnavailableException>().having(
            (error) => error.reason,
            'reason',
            SyncE2EKeyUnavailableReason.malformed,
          ),
        ),
      );
    });

    test('well-formed input of the wrong length fails', () {
      final short = Uint8List.fromList(
        List<int>.generate(16, (index) => index),
      );

      expect(
        () => decodeAndValidateSyncE2EKey(encodeKey(short)),
        throwsA(
          isA<SyncE2EKeyUnavailableException>().having(
            (error) => error.reason,
            'reason',
            SyncE2EKeyUnavailableReason.wrongLength,
          ),
        ),
      );
    });
  });
}
