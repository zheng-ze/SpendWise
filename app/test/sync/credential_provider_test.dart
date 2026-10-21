import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/store/device_identity.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';
import 'package:spendwise/sync/credential_provider.dart';
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

String validDeviceSecret([int fill = 0]) =>
    base64Url.encode(List.filled(32, fill)).replaceAll('=', '');

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
      final deviceSecret = validDeviceSecret();
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
      expect(secrets.reads, [syncDeviceSecretKey, syncCredentialSecretKey]);
    },
  );

  test(
    'withBoundCredentialAndSecret exposes the exact secret it bound',
    () async {
      final id = await deviceID(db);
      final credential = const CredentialCodec().restore(
        payload(id, 'test-bearer'),
      );
      await secrets.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(credential),
      );
      final deviceSecret = validDeviceSecret(7);
      await secrets.write(syncDeviceSecretKey, deviceSecret);

      final result = await provider.withBoundCredentialAndSecret((
        bound,
        secret,
      ) async {
        expect(secret, deviceSecret);
        expect(
          bound,
          BoundDeviceCredential.bind(credential, deviceSecret: secret),
        );
        return 'called';
      });

      expect(result, 'called');
      expect(secrets.reads, [syncDeviceSecretKey, syncCredentialSecretKey]);
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
    expect(secrets.reads, [syncDeviceSecretKey]);
  });

  test('device secret persists under the binding-secret key name', () {
    expect(syncDeviceSecretKey, 'spendwise.sync.device-binding-secret');
  });

  test('withBoundCredential rejects a malformed device secret', () async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      payload(id, 'test-bearer'),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    const malformed = 'leaked-malformed-secret';
    await secrets.write(syncDeviceSecretKey, malformed);
    secrets.reads.clear();
    var called = false;
    CredentialUnavailableException? thrown;
    try {
      await provider.withBoundCredential((_) => called = true);
    } on CredentialUnavailableException catch (error) {
      thrown = error;
    }
    expect(called, isFalse);
    expect(thrown, isNotNull);
    expect(thrown!.reason, CredentialUnavailableReason.deviceSecretMalformed);
    expect(thrown.toString(), isNot(contains(malformed)));
    expect(thrown.toString(), isNot(contains('test-bearer')));
    expect(secrets.reads, [syncDeviceSecretKey]);
  });

  test('session and bound resolution stay independent of each key', () async {
    final id = await deviceID(db);
    final first = const CredentialCodec().restore(payload(id, 'first-bearer'));
    final second = const CredentialCodec().restore(
      payload(id, 'second-bearer'),
    );
    final deviceSecret = validDeviceSecret();
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(first),
    );
    await secrets.write(syncDeviceSecretKey, deviceSecret);

    secrets.reads.clear();
    secrets.writes.clear();
    await provider.withSessionCredential((_) => 'session');
    expect(secrets.reads, [syncCredentialSecretKey]);

    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(second),
    );
    expect(secrets.writes, isNot(contains(syncDeviceSecretKey)));
    secrets.reads.clear();
    final rebound = await provider.withBoundCredential((bound) => bound);
    expect(
      rebound,
      BoundDeviceCredential.bind(second, deviceSecret: deviceSecret),
    );
    expect(secrets.reads, [syncDeviceSecretKey, syncCredentialSecretKey]);
    expect(await secrets.read(syncDeviceSecretKey), deviceSecret);

    await secrets.delete(syncDeviceSecretKey);
    final stillSession = await provider.withSessionCredential(
      (credential) => credential,
    );
    expect(stillSession, second);

    secrets.writes.clear();
    await secrets.write(syncDeviceSecretKey, deviceSecret);
    expect(secrets.writes, isNot(contains(syncCredentialSecretKey)));
    await secrets.delete(syncCredentialSecretKey);
    expect(await secrets.read(syncDeviceSecretKey), deviceSecret);
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
    expect(await secrets.read(syncDeviceSecretKey), deviceSecret);
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
      await secrets.write(syncDeviceSecretKey, validDeviceSecret(1));
      await provider.withBoundCredential((bound) {
        expect(
          bound,
          BoundDeviceCredential.bind(
            credential,
            deviceSecret: validDeviceSecret(1),
          ),
        );
      });
      await secrets.write(syncDeviceSecretKey, validDeviceSecret(2));
      await provider.withBoundCredential((bound) {
        expect(
          bound,
          BoundDeviceCredential.bind(
            credential,
            deviceSecret: validDeviceSecret(2),
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
        syncDeviceSecretKey,
        syncCredentialSecretKey,
        syncDeviceSecretKey,
        syncCredentialSecretKey,
        syncDeviceSecretKey,
      ]);
    },
  );

  test('bound failures never expose the device secret value', () async {
    final deviceSecret = validDeviceSecret();
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
    final deviceSecret = validDeviceSecret();
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
    expect(secrets.reads, [syncDeviceSecretKey]);
  });
}
