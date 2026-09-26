import 'package:sync/sync.dart';
import 'package:test/test.dart';

import '../support/credential_fixture.dart';

const _deviceID = 'device-a';
const _bearer = 'bearer-1';
const _secret = 'device-secret-1';

InMemorySyncBackend provisioned({DateTime Function()? clock}) {
  final backend = InMemorySyncBackend(clock: clock);
  backend.provisionBoundDevice(
    deviceID: _deviceID,
    bearerToken: _bearer,
    deviceSecret: _secret,
  );
  return backend;
}

BoundDeviceCredential boundCredential({
  String bearerToken = _bearer,
  String deviceSecret = _secret,
}) =>
    bindTestCredential(
      deviceID: _deviceID,
      bearerToken: bearerToken,
      deviceSecret: deviceSecret,
    );

DeviceCredential bearerCredential({String bearerToken = _bearer}) =>
    restoreTestCredential(deviceID: _deviceID, bearerToken: bearerToken);

PullRequest pullAll() => const PullRequest(collection: SyncCollection.entries);

Future<VerifyDeviceBindingResponse> verifiedResponse(
  InMemorySyncBackend backend, {
  String deviceID = _deviceID,
}) async {
  final start = await backend.startBinding(
    StartDeviceBindingRequest(
      identifier: 'user@example.com',
      deviceID: deviceID,
    ),
  );
  final challenge = (start as SyncSuccess<StartDeviceBindingResponse>).value;
  final verify = await backend.verifyBinding(
    VerifyDeviceBindingRequest(
      challengeID: challenge.challengeID,
      identifier: 'user@example.com',
      deviceID: deviceID,
      otp: InMemorySyncBackend.bindingOtp,
    ),
  );
  return (verify as SyncSuccess<VerifyDeviceBindingResponse>).value;
}

void main() {
  group('binding enforcement', () {
    test('a bearer without the device secret cannot use a bound device id',
        () async {
      final backend = provisioned();

      final outcome = await backend.pull(
        bearerCredential(),
        pullAll(),
      );

      expect(outcome, isA<DeviceAuthorizationRequired<PullResponse>>());
    });

    test('a bound credential with the current secret succeeds', () async {
      final backend = provisioned();

      expect(
        await backend.pull(boundCredential(), pullAll()),
        isA<SyncSuccess<PullResponse>>(),
      );
      expect(
        await backend.push(boundCredential(), PushRequest(envelopes: const [])),
        isA<SyncSuccess<PushResponse>>(),
      );
      expect(
        await backend.acknowledge(
          boundCredential(),
          const AcknowledgeRequest(
            collection: SyncCollection.entries,
            checkpoint: 'checkpoint-1',
          ),
        ),
        isA<SyncSuccess<AcknowledgeResponse>>(),
      );
    });

    test('a wrong device secret fails closed', () async {
      final backend = provisioned();

      final outcome = await backend.pull(
        boundCredential(deviceSecret: 'stale-secret'),
        pullAll(),
      );

      expect(outcome, isA<DeviceAuthorizationRequired<PullResponse>>());
    });

    test('complete reconcile requires the current secret', () async {
      final backend = provisioned();
      CompleteReconcile complete() => CompleteReconcile(
            collectionHashes: {
              for (final collection in SyncCollection.values)
                collection: 'hash',
            },
          );

      expect(
        await backend.reconcile(boundCredential(), complete()),
        isA<SyncSuccess<ReconcileResponse>>(),
      );
      expect(
        await backend.reconcile(bearerCredential(), complete()),
        isA<DeviceAuthorizationRequired<ReconcileResponse>>(),
      );
    });
  });

  group('bearer expiry', () {
    test('an expired bearer enters session reauth, not binding repair',
        () async {
      final backend = provisioned();
      backend.expireBearer(_deviceID);

      final outcome = await backend.pull(
        boundCredential(),
        pullAll(),
      );

      expect(outcome, isA<CredentialExpired<PullResponse>>());
      expect(outcome, isNot(isA<DeviceAuthorizationRequired<PullResponse>>()));
    });

    test('a new bearer combines with the stored secret', () async {
      final backend = provisioned();
      backend.updateBearer(_deviceID, 'bearer-2');

      final outcome = await backend.pull(
        boundCredential(bearerToken: 'bearer-2'),
        pullAll(),
      );

      expect(outcome, isA<SyncSuccess<PullResponse>>());
    });
  });

  group('retirement', () {
    test('a retired device stays retired across calls', () async {
      final backend = provisioned();
      backend.retireDevice(_deviceID);

      expect(
        await backend.pull(boundCredential(), pullAll()),
        isA<DeviceRetired<PullResponse>>(),
      );
      expect(
        await backend.push(boundCredential(), PushRequest(envelopes: const [])),
        isA<DeviceRetired<PushResponse>>(),
      );
    });

    test('verify reactivates a retired device', () async {
      final backend = provisioned();
      backend.retireDevice(_deviceID);
      final response = await verifiedResponse(backend);
      final bound = BoundDeviceCredential.bind(
        response.sessionCredential(_deviceID),
        deviceSecret: _boundSecretOf(
          await backend.reconcile(
            response.sessionCredential(_deviceID),
            response.authorizeBegin(),
          ),
        ),
      );

      final outcome = await backend.pull(bound, pullAll());

      expect(outcome, isA<SyncSuccess<PullResponse>>());
    });
  });

  group('protocol-major enforcement', () {
    test('startBinding rejects a legacy protocol major', () async {
      final backend = provisioned();

      final outcome = await backend.startBinding(
        StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: _deviceID,
          protocolMajor: 1,
        ),
      );

      expect(outcome, isA<ProtocolUnsupported<StartDeviceBindingResponse>>());
    });

    test('verifyBinding rejects a legacy protocol major', () async {
      final backend = provisioned();

      final outcome = await backend.verifyBinding(
        VerifyDeviceBindingRequest(
          challengeID: 'challenge-1',
          identifier: 'user@example.com',
          deviceID: _deviceID,
          otp: '123456',
          protocolMajor: 1,
        ),
      );

      expect(outcome, isA<ProtocolUnsupported<VerifyDeviceBindingResponse>>());
    });
  });

  group('challenge lifecycle', () {
    test('a wrong otp fails closed', () async {
      final backend = provisioned();
      final start = await backend.startBinding(
        StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: _deviceID,
        ),
      );
      final challenge =
          (start as SyncSuccess<StartDeviceBindingResponse>).value;

      final outcome = await backend.verifyBinding(
        VerifyDeviceBindingRequest(
          challengeID: challenge.challengeID,
          identifier: 'user@example.com',
          deviceID: _deviceID,
          otp: '000000',
        ),
      );

      expect(outcome,
          isA<DeviceAuthorizationRequired<VerifyDeviceBindingResponse>>());
    });

    test('a consumed challenge cannot be replayed', () async {
      final backend = provisioned();
      final start = await backend.startBinding(
        StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: _deviceID,
        ),
      );
      final challenge =
          (start as SyncSuccess<StartDeviceBindingResponse>).value;
      VerifyDeviceBindingRequest verify() => VerifyDeviceBindingRequest(
            challengeID: challenge.challengeID,
            identifier: 'user@example.com',
            deviceID: _deviceID,
            otp: InMemorySyncBackend.bindingOtp,
          );

      expect(await backend.verifyBinding(verify()),
          isA<SyncSuccess<VerifyDeviceBindingResponse>>());
      expect(await backend.verifyBinding(verify()),
          isA<DeviceAuthorizationRequired<VerifyDeviceBindingResponse>>());
    });

    test('an expired challenge fails closed', () async {
      var now = DateTime.utc(2026, 9, 19, 12);
      final backend = provisioned(clock: () => now);
      final start = await backend.startBinding(
        StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: _deviceID,
        ),
      );
      final challenge =
          (start as SyncSuccess<StartDeviceBindingResponse>).value;
      now = now.add(const Duration(minutes: 11));

      final outcome = await backend.verifyBinding(
        VerifyDeviceBindingRequest(
          challengeID: challenge.challengeID,
          identifier: 'user@example.com',
          deviceID: _deviceID,
          otp: InMemorySyncBackend.bindingOtp,
        ),
      );

      expect(outcome,
          isA<DeviceAuthorizationRequired<VerifyDeviceBindingResponse>>());
    });
  });

  group('authorization-bearing Begin', () {
    test('creates the binding and returns one device secret', () async {
      final backend = InMemorySyncBackend();
      final response =
          await verifiedResponse(backend, deviceID: 'fresh-device');

      final outcome = await backend.reconcile(
        response.sessionCredential('fresh-device'),
        response.authorizeBegin(),
      );

      final success = outcome as SyncSuccess<ReconcileResponse>;
      final secret = success.value.wire['device_secret'];
      expect(secret, isA<String>());
      expect((secret as String), isNotEmpty);
      expect(success.value.wire['generation'], 1);
    });

    test('rotates the secret and generation on a bound device', () async {
      final backend = provisioned();
      final response = await verifiedResponse(backend);
      final outcome = await backend.reconcile(
        response.sessionCredential(_deviceID),
        response.authorizeBegin(),
      );

      final success = outcome as SyncSuccess<ReconcileResponse>;
      final rotated = success.value.wire['device_secret'] as String;
      expect(rotated, isNot(_secret));
      expect(success.value.wire['generation'], 2);

      final staleSecret = BoundDeviceCredential.bind(
        response.sessionCredential(_deviceID),
        deviceSecret: _secret,
      );
      expect(
        await backend.pull(staleSecret, pullAll()),
        isA<DeviceAuthorizationRequired<PullResponse>>(),
      );
      final rebound = BoundDeviceCredential.bind(
        response.sessionCredential(_deviceID),
        deviceSecret: rotated,
      );
      expect(
        await backend.pull(rebound, pullAll()),
        isA<SyncSuccess<PullResponse>>(),
      );
    });

    test('an authorization is single-use', () async {
      final backend = provisioned();
      final response = await verifiedResponse(backend);
      final session = response.sessionCredential(_deviceID);

      expect(
        await backend.reconcile(session, response.authorizeBegin()),
        isA<SyncSuccess<ReconcileResponse>>(),
      );
      expect(
        await backend.reconcile(session, response.authorizeBegin()),
        isA<DeviceAuthorizationRequired<ReconcileResponse>>(),
      );
    });

    test('an expired authorization fails closed', () async {
      var now = DateTime.utc(2026, 9, 19, 12);
      final backend = provisioned(clock: () => now);
      final response = await verifiedResponse(backend);
      now = now.add(const Duration(minutes: 11));

      final outcome = await backend.reconcile(
        response.sessionCredential(_deviceID),
        response.authorizeBegin(),
      );

      expect(outcome, isA<DeviceAuthorizationRequired<ReconcileResponse>>());
    });
    test('an ordinary bound Begin never rotates or returns a secret', () async {
      final backend = provisioned();

      final outcome =
          await backend.reconcile(boundCredential(), const BeginReconcile());

      final success = outcome as SyncSuccess<ReconcileResponse>;
      expect(success.value.wire.containsKey('device_secret'), isFalse);
      expect(success.value.wire['generation'], 1);
      expect(
        await backend.pull(boundCredential(), pullAll()),
        isA<SyncSuccess<PullResponse>>(),
      );
    });

    test('verification alone leaves the prior secret gating', () async {
      final backend = provisioned();
      final response = await verifiedResponse(backend);

      final prior = BoundDeviceCredential.bind(
        response.sessionCredential(_deviceID),
        deviceSecret: _secret,
      );
      final outcome = await backend.reconcile(
        prior,
        const BeginReconcile(),
      );

      final success = outcome as SyncSuccess<ReconcileResponse>;
      expect(success.value.wire['generation'], 1);
      expect(success.value.wire.containsKey('device_secret'), isFalse);
    });

    test('a lost verify response retries without silent double rotation',
        () async {
      final backend = provisioned();
      final first = await verifiedResponse(backend);
      final second = await verifiedResponse(backend);

      final superseded = await backend.reconcile(
        first.sessionCredential(_deviceID),
        first.authorizeBegin(),
      );
      expect(superseded, isNot(isA<SyncSuccess<ReconcileResponse>>()));

      final outcome = await backend.reconcile(
        second.sessionCredential(_deviceID),
        second.authorizeBegin(),
      );
      expect(
        (outcome as SyncSuccess<ReconcileResponse>).value.wire['generation'],
        2,
      );
    });
  });

  group('authorization scope', () {
    test('verify rejects a mismatched identifier', () async {
      final backend = provisioned();
      final start = await backend.startBinding(
        StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: _deviceID,
        ),
      );
      final challenge =
          (start as SyncSuccess<StartDeviceBindingResponse>).value;

      final outcome = await backend.verifyBinding(
        VerifyDeviceBindingRequest(
          challengeID: challenge.challengeID,
          identifier: 'other@example.com',
          deviceID: _deviceID,
          otp: InMemorySyncBackend.bindingOtp,
        ),
      );

      expect(outcome,
          isA<DeviceAuthorizationRequired<VerifyDeviceBindingResponse>>());
    });

    test('an authorization does not survive routine reauth', () async {
      final backend = provisioned();
      final response = await verifiedResponse(backend);
      backend.updateBearer(_deviceID, 'bearer-2');

      final outcome = await backend.reconcile(
        restoreTestCredential(deviceID: _deviceID, bearerToken: 'bearer-2'),
        response.authorizeBegin(),
      );

      expect(outcome, isA<DeviceAuthorizationRequired<ReconcileResponse>>());
    });
  });

  group('expiry boundaries', () {
    test('a challenge at exactly its expiry is rejected', () async {
      var now = DateTime.utc(2026, 9, 19, 12);
      final backend = provisioned(clock: () => now);
      final start = await backend.startBinding(
        StartDeviceBindingRequest(
          identifier: 'user@example.com',
          deviceID: _deviceID,
        ),
      );
      final challenge =
          (start as SyncSuccess<StartDeviceBindingResponse>).value;
      now = challenge.expiresAt;

      final outcome = await backend.verifyBinding(
        VerifyDeviceBindingRequest(
          challengeID: challenge.challengeID,
          identifier: 'user@example.com',
          deviceID: _deviceID,
          otp: InMemorySyncBackend.bindingOtp,
        ),
      );

      expect(outcome,
          isA<DeviceAuthorizationRequired<VerifyDeviceBindingResponse>>());
    });

    test('an authorization at exactly its expiry is rejected', () async {
      var now = DateTime.utc(2026, 9, 19, 12);
      final backend = provisioned(clock: () => now);
      final response = await verifiedResponse(backend);
      now = response.authorizationExpiresAt;

      final outcome = await backend.reconcile(
        response.sessionCredential(_deviceID),
        response.authorizeBegin(),
      );

      expect(outcome, isA<DeviceAuthorizationRequired<ReconcileResponse>>());
    });
  });

  group('redaction', () {
    test('failures, strings, and diagnostics expose no protected value',
        () async {
      const bearer = 'bearer-secret-value';
      const secret = 'device-secret-value';
      final backend = InMemorySyncBackend();
      backend.provisionBoundDevice(
        deviceID: _deviceID,
        bearerToken: bearer,
        deviceSecret: secret,
      );
      final bound = bindTestCredential(
        deviceID: _deviceID,
        bearerToken: bearer,
        deviceSecret: secret,
      );

      final inspected = <String>[
        bound.toString(),
        (await backend.pull(
          restoreTestCredential(deviceID: _deviceID, bearerToken: bearer),
          pullAll(),
        ))
            .toString(),
        (await backend.pull(
          bindTestCredential(
            deviceID: _deviceID,
            bearerToken: bearer,
            deviceSecret: 'wrong-secret',
          ),
          pullAll(),
        ))
            .toString(),
        backend.toString(),
      ];

      for (final text in inspected) {
        expect(text, isNot(contains(bearer)));
        expect(text, isNot(contains(secret)));
      }
    });
  });
}

String _boundSecretOf(SyncOutcome<ReconcileResponse> outcome) =>
    (outcome as SyncSuccess<ReconcileResponse>).value.wire['device_secret']
        as String;
