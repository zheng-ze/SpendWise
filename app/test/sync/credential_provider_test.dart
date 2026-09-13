import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

import 'in_memory_secret_store.dart';

String payload(String device, String bearer) => base64Url.encode(
  utf8.encode(
    jsonEncode({
      'deviceID': device,
      'bearerToken': base64Url.encode(utf8.encode(bearer)),
    }),
  ),
);

void main() {
  late LedgerDatabase db;
  late InMemorySecretStore secrets;
  late CredentialProvider provider;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    provider = CredentialProvider(database: db, secretStore: secrets);
  });

  tearDown(() => db.close());

  test(
    'restores a persisted credential for the matching device callback',
    () async {
      final id = await deviceID(db);
      final credential = const CredentialCodec().restore(
        payload(id, 'test-bearer'),
      );
      await secrets.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(credential),
      );
      await secrets.write(syncE2EKeySecretKey, 'separate-test-key');

      final result = await provider.withCredential((restored) async {
        expect(restored, credential);
        expect(restored.deviceID, id);
        return 'called';
      });

      expect(result, 'called');
      expect(secrets.reads, [syncCredentialSecretKey]);
      expect(await secrets.read(syncE2EKeySecretKey), 'separate-test-key');
    },
  );

  test('rejects a credential belonging to another device before use', () async {
    await secrets.write(
      syncCredentialSecretKey,
      payload('another-device', 'test-bearer'),
    );
    var called = false;

    await expectLater(
      provider.withCredential((_) => called = true),
      throwsA(
        isA<CredentialUnavailableException>()
            .having(
              (error) => error.reason,
              'reason',
              CredentialUnavailableReason.identityFailed,
            )
            .having(
              (error) => error.toString(),
              'message',
              'Sync credential unavailable (identityFailed).',
            ),
      ),
    );

    expect(called, isFalse);
  });

  test(
    'missing credentials fail with a fixed redacted error before use',
    () async {
      var called = false;

      await expectLater(
        provider.withCredential((_) => called = true),
        throwsA(
          isA<CredentialUnavailableException>()
              .having(
                (error) => error.reason,
                'reason',
                CredentialUnavailableReason.absent,
              )
              .having(
                (error) => error.toString(),
                'message',
                'Sync credential unavailable (absent).',
              ),
        ),
      );

      expect(called, isFalse);
    },
  );

  test(
    'malformed stored payloads fail without exposing secret content',
    () async {
      final malformed = base64Url.encode(utf8.encode('test-bearer-secret'));
      await secrets.write(syncCredentialSecretKey, malformed);
      var called = false;

      await expectLater(
        provider.withCredential((_) => called = true),
        throwsA(
          isA<CredentialUnavailableException>()
              .having(
                (error) => error.reason,
                'reason',
                CredentialUnavailableReason.malformed,
              )
              .having(
                (error) => error.toString(),
                'message',
                'Sync credential unavailable (malformed).',
              ),
        ),
      );

      expect(called, isFalse);
      expect(provider.toString(), isNot(contains(malformed)));
      expect(provider.toString(), isNot(contains('test-bearer-secret')));
    },
  );

  test('storage failures cannot leak their exception contents', () async {
    secrets.readFailure = StateError('test-bearer-secret opaque-payload');
    var called = false;

    await expectLater(
      provider.withCredential((_) => called = true),
      throwsA(
        isA<CredentialUnavailableException>()
            .having(
              (error) => error.reason,
              'reason',
              CredentialUnavailableReason.storageFailed,
            )
            .having(
              (error) => error.toString(),
              'message',
              'Sync credential unavailable (storageFailed).',
            ),
      ),
    );
    expect(called, isFalse);
  });

  test('identity lookup failures prevent credential use', () async {
    await secrets.write(
      syncCredentialSecretKey,
      payload('device', 'test-bearer'),
    );
    await db.close();
    db = LedgerDatabase(
      NativeDatabase.memory(
        setup: (_) => throw StateError('test-private-database-details'),
      ),
    );
    provider = CredentialProvider(database: db, secretStore: secrets);
    var called = false;

    await expectLater(
      provider.withCredential((_) => called = true),
      throwsA(
        isA<CredentialUnavailableException>().having(
          (error) => error.reason,
          'reason',
          CredentialUnavailableReason.identityFailed,
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('storage failure and absence keep distinct redacted reasons', () async {
    Future<CredentialUnavailableException> unavailableFrom(
      Future<void> Function() action,
    ) async {
      try {
        await action();
      } on CredentialUnavailableException catch (error) {
        return error;
      }
      throw StateError('Expected credential unavailability.');
    }

    secrets.readFailure = const SecretStoreException();
    final storageUnavailable = await unavailableFrom(
      () => provider.withCredential(
        (_) => fail('A storage failure used a credential.'),
      ),
    );
    secrets.readFailure = null;
    final absentUnavailable = await unavailableFrom(
      () => provider.withCredential(
        (_) => fail('An absent credential was used.'),
      ),
    );

    expect(storageUnavailable.reason, isNot(absentUnavailable.reason));
    expect(storageUnavailable.toString(), isNot(contains('test-bearer')));
    expect(storageUnavailable.toString(), isNot(contains('db-error')));
    expect(absentUnavailable.toString(), isNot(contains('test-bearer')));
    expect(absentUnavailable.toString(), isNot(contains('db-error')));
  });

  test(
    'each call restores the current payload and observes deletion',
    () async {
      final id = await deviceID(db);
      final firstPayload = payload(id, 'first-test-bearer');
      final secondPayload = payload(id, 'second-test-bearer');
      await secrets.write(syncCredentialSecretKey, firstPayload);
      await provider.withCredential((credential) {
        expect(credential, const CredentialCodec().restore(firstPayload));
      });
      await secrets.write(syncCredentialSecretKey, secondPayload);
      await provider.withCredential((credential) {
        expect(credential, const CredentialCodec().restore(secondPayload));
        expect(
          credential,
          isNot(const CredentialCodec().restore(firstPayload)),
        );
        expect(credential.toString(), isNot(contains('second-test-bearer')));
      });
      await secrets.delete(syncCredentialSecretKey);
      await expectLater(
        provider.withCredential(
          (_) => fail('A deleted credential was reused.'),
        ),
        throwsA(isA<CredentialUnavailableException>()),
      );
      expect(secrets.reads, List.filled(3, syncCredentialSecretKey));
    },
  );

  test(
    'overlapping callbacks use independently restored credentials',
    () async {
      final id = await deviceID(db);
      final first = payload(id, 'first-test-bearer');
      final second = payload(id, 'second-test-bearer');
      final entered = Completer<void>();
      final release = Completer<void>();
      await secrets.write(syncCredentialSecretKey, first);
      final firstCall = provider.withCredential((credential) async {
        entered.complete();
        await release.future;
        return credential == const CredentialCodec().restore(first);
      });
      await entered.future;
      await secrets.write(syncCredentialSecretKey, second);
      try {
        expect(
          await provider.withCredential(
            (credential) =>
                credential == const CredentialCodec().restore(second),
          ),
          isTrue,
        );
      } finally {
        release.complete();
      }
      expect(await firstCall, isTrue);
      expect(secrets.reads, List.filled(2, syncCredentialSecretKey));
    },
  );
}
