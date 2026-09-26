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

      final result = await provider.withSessionCredential((restored) async {
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
      provider.withSessionCredential((_) => called = true),
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
        provider.withSessionCredential((_) => called = true),
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
        provider.withSessionCredential((_) => called = true),
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
      provider.withSessionCredential((_) => called = true),
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
      provider.withSessionCredential((_) => called = true),
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
      () => provider.withSessionCredential(
        (_) => fail('A storage failure used a credential.'),
      ),
    );
    secrets.readFailure = null;
    final absentUnavailable = await unavailableFrom(
      () => provider.withSessionCredential(
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
      await provider.withSessionCredential((credential) {
        expect(credential, const CredentialCodec().restore(firstPayload));
      });
      await secrets.write(syncCredentialSecretKey, secondPayload);
      await provider.withSessionCredential((credential) {
        expect(credential, const CredentialCodec().restore(secondPayload));
        expect(
          credential,
          isNot(const CredentialCodec().restore(firstPayload)),
        );
        expect(credential.toString(), isNot(contains('second-test-bearer')));
      });
      await secrets.delete(syncCredentialSecretKey);
      await expectLater(
        provider.withSessionCredential(
          (_) => fail('A deleted credential was reused.'),
        ),
        throwsA(isA<CredentialUnavailableException>()),
      );
      expect(secrets.reads, List.filled(3, syncCredentialSecretKey));
    },
  );

  test(
    'withBoundCredential binds the session credential to the device secret',
    () async {
      final id = await deviceID(db);
      final credential = const CredentialCodec().restore(
        payload(id, 'test-bearer'),
      );
      await secrets.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(credential),
      );
      const deviceSecret = 'test-device-secret';
      await secrets.write(syncDeviceSecretKey, deviceSecret);

      final result = await provider.withBoundCredential((bound) async {
        expect(
          bound,
          BoundDeviceCredential.bind(credential, deviceSecret: deviceSecret),
        );
        expect(bound.deviceID, id);
        return 'called';
      });

      expect(result, 'called');
      expect(secrets.reads, [syncCredentialSecretKey, syncDeviceSecretKey]);
    },
  );

  test('withBoundCredential throws when the device secret is absent', () async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      payload(id, 'test-bearer'),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    var called = false;

    await expectLater(
      provider.withBoundCredential((_) => called = true),
      throwsA(
        isA<CredentialUnavailableException>()
            .having(
              (error) => error.reason,
              'reason',
              CredentialUnavailableReason.deviceSecretAbsent,
            )
            .having(
              (error) => error.toString(),
              'message',
              'Sync credential unavailable (deviceSecretAbsent).',
            ),
      ),
    );

    expect(called, isFalse);
  });

  test('session and bound resolution stay independent of each key', () async {
    final id = await deviceID(db);
    final first = const CredentialCodec().restore(payload(id, 'first-bearer'));
    final second = const CredentialCodec().restore(
      payload(id, 'second-bearer'),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(first),
    );
    await secrets.write(syncDeviceSecretKey, 'test-device-secret');

    secrets.reads.clear();
    secrets.writes.clear();
    await provider.withSessionCredential((_) => 'session');
    expect(secrets.reads, [syncCredentialSecretKey]);

    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(second),
    );
    expect(secrets.writes, isNot(contains(syncDeviceSecretKey)));
    final rebound = await provider.withBoundCredential((bound) => bound);
    expect(
      rebound,
      BoundDeviceCredential.bind(second, deviceSecret: 'test-device-secret'),
    );
    expect(await secrets.read(syncDeviceSecretKey), 'test-device-secret');

    await secrets.delete(syncDeviceSecretKey);
    final stillSession = await provider.withSessionCredential(
      (credential) => credential,
    );
    expect(stillSession, second);

    secrets.writes.clear();
    await secrets.write(syncDeviceSecretKey, 'test-device-secret');
    expect(secrets.writes, isNot(contains(syncCredentialSecretKey)));
    await secrets.delete(syncCredentialSecretKey);
    expect(await secrets.read(syncDeviceSecretKey), 'test-device-secret');
    var called = false;
    await expectLater(
      provider.withBoundCredential((_) => called = true),
      throwsA(
        isA<CredentialUnavailableException>().having(
          (error) => error.reason,
          'reason',
          CredentialUnavailableReason.absent,
        ),
      ),
    );
    expect(called, isFalse);
    expect(await secrets.read(syncDeviceSecretKey), 'test-device-secret');
  });

  test(
    'each bound call restores the current secret and observes deletion',
    () async {
      final id = await deviceID(db);
      final credential = const CredentialCodec().restore(
        payload(id, 'test-bearer'),
      );
      await secrets.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(credential),
      );
      await secrets.write(syncDeviceSecretKey, 'first-device-secret');
      await provider.withBoundCredential((bound) {
        expect(
          bound,
          BoundDeviceCredential.bind(
            credential,
            deviceSecret: 'first-device-secret',
          ),
        );
      });
      await secrets.write(syncDeviceSecretKey, 'second-device-secret');
      await provider.withBoundCredential((bound) {
        expect(
          bound,
          BoundDeviceCredential.bind(
            credential,
            deviceSecret: 'second-device-secret',
          ),
        );
      });
      await secrets.delete(syncDeviceSecretKey);
      await expectLater(
        provider.withBoundCredential(
          (_) => fail('A deleted device secret was reused.'),
        ),
        throwsA(
          isA<CredentialUnavailableException>().having(
            (error) => error.reason,
            'reason',
            CredentialUnavailableReason.deviceSecretAbsent,
          ),
        ),
      );
      expect(secrets.reads, [
        syncCredentialSecretKey,
        syncDeviceSecretKey,
        syncCredentialSecretKey,
        syncDeviceSecretKey,
        syncCredentialSecretKey,
        syncDeviceSecretKey,
      ]);
    },
  );

  test('bound failures never expose the device secret value', () async {
    const deviceSecret = 'test-device-secret-value';
    await secrets.write(
      syncCredentialSecretKey,
      payload('another-device', 'test-bearer'),
    );
    await secrets.write(syncDeviceSecretKey, deviceSecret);
    var called = false;

    await expectLater(
      provider.withBoundCredential((_) => called = true),
      throwsA(
        isA<CredentialUnavailableException>().having(
          (error) => error.reason,
          'reason',
          CredentialUnavailableReason.identityFailed,
        ),
      ),
    );

    expect(called, isFalse);
    CredentialUnavailableException? thrown;
    try {
      await provider.withBoundCredential((_) => 'unreachable');
    } on CredentialUnavailableException catch (error) {
      thrown = error;
    }
    expect(thrown, isNotNull);
    expect(thrown.toString(), isNot(contains(deviceSecret)));
    expect(thrown.toString(), isNot(contains('test-bearer')));
  });

  test('bound device-secret storage failures stay redacted', () async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      payload(id, 'test-bearer'),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    const deviceSecret = 'test-device-secret-value';
    await secrets.write(syncDeviceSecretKey, deviceSecret);
    secrets.readFailure = StateError('test-bearer-secret opaque-payload');
    secrets.readFailureKey = syncDeviceSecretKey;
    var called = false;

    CredentialUnavailableException? thrown;
    try {
      await provider.withBoundCredential((_) => called = true);
    } on CredentialUnavailableException catch (error) {
      thrown = error;
    }

    expect(called, isFalse);
    expect(thrown, isNotNull);
    expect(thrown!.reason, CredentialUnavailableReason.storageFailed);
    expect(thrown.toString(), 'Sync credential unavailable (storageFailed).');
    expect(thrown.toString(), isNot(contains('test-bearer-secret')));
    expect(thrown.toString(), isNot(contains('opaque-payload')));
    expect(thrown.toString(), isNot(contains(deviceSecret)));
    expect(secrets.reads, [syncCredentialSecretKey, syncDeviceSecretKey]);
  });

  test(
    'overlapping callbacks use independently restored credentials',
    () async {
      final id = await deviceID(db);
      final first = payload(id, 'first-test-bearer');
      final second = payload(id, 'second-test-bearer');
      final entered = Completer<void>();
      final release = Completer<void>();
      await secrets.write(syncCredentialSecretKey, first);
      final firstCall = provider.withSessionCredential((credential) async {
        entered.complete();
        await release.future;
        return credential == const CredentialCodec().restore(first);
      });
      await entered.future;
      await secrets.write(syncCredentialSecretKey, second);
      try {
        expect(
          await provider.withSessionCredential(
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
