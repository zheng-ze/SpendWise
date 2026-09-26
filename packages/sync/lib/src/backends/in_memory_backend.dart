part of '../../sync.dart';

typedef PushHandler = Future<SyncOutcome<PushResponse>> Function(
  SyncCredential credential,
  PushRequest request,
);
typedef PullHandler = Future<SyncOutcome<PullResponse>> Function(
  SyncCredential credential,
  PullRequest request,
);
typedef ReconcileHandler = Future<SyncOutcome<ReconcileResponse>> Function(
  SyncCredential credential,
  ReconcileRequest request,
);
typedef AcknowledgeHandler = Future<SyncOutcome<AcknowledgeResponse>> Function(
  SyncCredential credential,
  AcknowledgeRequest request,
);

final class _EmulatedBinding {
  _EmulatedBinding({
    required this.bearerToken,
    required this.deviceSecret,
    required this.generation,
  });

  String bearerToken;
  String? deviceSecret;
  int generation;
  bool retired = false;
  bool bearerExpired = false;
}

final class _EmulatedChallenge {
  _EmulatedChallenge({
    required this.challengeID,
    required this.identifier,
    required this.deviceID,
    required this.expiresAt,
  });

  final String challengeID;
  final String identifier;
  final String deviceID;
  final DateTime expiresAt;
}

final class _EmulatedAuthorization {
  _EmulatedAuthorization({
    required this.token,
    required this.deviceID,
    required this.generation,
    required this.sessionBearer,
    required this.priorBearer,
    required this.expiresAt,
  });

  final String token;
  final String deviceID;
  final int generation;
  final String sessionBearer;
  final String? priorBearer;
  final DateTime expiresAt;
  bool consumed = false;
}

/// Lightweight fake for coordinator and adapter-contract tests.
///
/// It deliberately does not simulate server causality, cursor, proof, or GC
/// semantics; those belong in the real server/adapter contract test harness.
///
/// Beyond the pass-through behavior, it emulates the v2 binding contract for
/// provisioned devices: bearer expiry, retirement, secret verification,
/// rotation through the start/verify/authorized-Begin chain, and
/// single-use expiring authorizations. Device IDs with no provisioned binding
/// keep the legacy pass-through so existing coordinator tests are unaffected.
final class InMemorySyncBackend
    implements SyncBackend, DeviceBindingAuthorizer {
  InMemorySyncBackend({
    PushHandler? onPush,
    PullHandler? onPull,
    ReconcileHandler? onReconcile,
    AcknowledgeHandler? onAcknowledge,
    DateTime Function()? clock,
  })  : _onPush = onPush,
        _onPull = onPull,
        _onReconcile = onReconcile,
        _onAcknowledge = onAcknowledge,
        _clock = clock ?? (() => DateTime.now().toUtc());

  /// The OTP this fake accepts; the real OTP arrives out-of-band.
  static const String bindingOtp = '123456';

  static const Duration _challengeLifetime = Duration(minutes: 10);
  static const Duration _authorizationLifetime = Duration(minutes: 10);

  final PushHandler? _onPush;
  final PullHandler? _onPull;
  final ReconcileHandler? _onReconcile;
  final AcknowledgeHandler? _onAcknowledge;
  final DateTime Function() _clock;

  final Map<String, _EmulatedBinding> _bindings = {};
  final Map<String, _EmulatedChallenge> _challenges = {};
  final Map<String, _EmulatedAuthorization> _authorizations = {};
  int _sequence = 0;

  final List<String> calls = <String>[];

  void provisionBoundDevice({
    required String deviceID,
    required String bearerToken,
    required String deviceSecret,
    int generation = 1,
  }) {
    _bindings[normalizedID(deviceID)] = _EmulatedBinding(
      bearerToken: bearerToken,
      deviceSecret: deviceSecret,
      generation: generation,
    );
  }

  void expireBearer(String deviceID) {
    _bindings[normalizedID(deviceID)]?.bearerExpired = true;
  }

  void updateBearer(String deviceID, String bearerToken) {
    final binding = _bindings[normalizedID(deviceID)];
    if (binding != null) {
      binding.bearerToken = bearerToken;
      binding.bearerExpired = false;
    }
  }

  void retireDevice(String deviceID) {
    _bindings[normalizedID(deviceID)]?.retired = true;
  }

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) async {
    calls.add('push');
    final gate = _gate<PushResponse>(credential);
    if (gate != null) return gate;
    return _onPush?.call(credential, request) ??
        SyncSuccess(PushResponse(const {}));
  }

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async {
    calls.add('pull');
    final gate = _gate<PullResponse>(credential);
    if (gate != null) return gate;
    return _onPull?.call(credential, request) ??
        SyncSuccess(PullResponse(const {}));
  }

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) async {
    calls.add('reconcile');
    final authorization =
        request is BeginReconcile ? request._bindingAuthorization : null;
    if (authorization != null) {
      return _authorizedBegin(credential, authorization);
    }
    final gate = _gate<ReconcileResponse>(credential);
    if (gate != null) return gate;
    final deviceID = _deviceIDOf(credential);
    if (request is BeginReconcile && _bindings.containsKey(deviceID)) {
      return SyncSuccess(_boundContext(deviceID, null));
    }
    return _onReconcile?.call(credential, request) ??
        SyncSuccess(ReconcileResponse(const {}));
  }

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) async {
    calls.add('acknowledge');
    final gate = _gate<AcknowledgeResponse>(credential);
    if (gate != null) return gate;
    return _onAcknowledge?.call(credential, request) ??
        SyncSuccess(AcknowledgeResponse(const {}));
  }

  @override
  Future<SyncOutcome<StartDeviceBindingResponse>> startBinding(
    StartDeviceBindingRequest request,
  ) async {
    calls.add('startBinding');
    if (request.protocolMajor != syncOperationMajor) {
      return const ProtocolUnsupported<StartDeviceBindingResponse>(
        message: 'Binding requires operation major 2.',
      );
    }
    final challengeID = 'challenge-${++_sequence}';
    final expiresAt = _clock().add(_challengeLifetime);
    _challenges[challengeID] = _EmulatedChallenge(
      challengeID: challengeID,
      identifier: request.identifier,
      deviceID: request.deviceID,
      expiresAt: expiresAt,
    );
    return SyncSuccess(
      StartDeviceBindingResponse(
        challengeID: challengeID,
        expiresAt: expiresAt,
      ),
    );
  }

  @override
  Future<SyncOutcome<VerifyDeviceBindingResponse>> verifyBinding(
    VerifyDeviceBindingRequest request,
  ) async {
    calls.add('verifyBinding');
    if (request.protocolMajor != syncOperationMajor) {
      return const ProtocolUnsupported<VerifyDeviceBindingResponse>(
        message: 'Binding requires operation major 2.',
      );
    }
    // Only peek at the challenge here: a device-ID, identifier, or OTP
    // mismatch must leave a still-valid challenge available for a retry with
    // the correct fields, exactly like a wrong-OTP attempt already does.
    final challenge = _challenges[request.challengeID];
    if (challenge == null ||
        challenge.deviceID != request.deviceID ||
        challenge.identifier != request.identifier ||
        !_clock().isBefore(challenge.expiresAt)) {
      return const DeviceAuthorizationRequired<VerifyDeviceBindingResponse>(
        message: 'Binding challenge is unknown or expired.',
      );
    }
    if (request.otp != bindingOtp) {
      return const DeviceAuthorizationRequired<VerifyDeviceBindingResponse>(
        message: 'Binding challenge failed.',
      );
    }
    _challenges.remove(request.challengeID);
    // Verification alone rotates nothing durable: an existing binding's
    // bearer, secret, generation, and retirement all stay untouched here, so
    // an abandoned or lost verify response never disturbs an already-working
    // session. Only a brand-new device gets a binding row at all (lazily, per
    // the plan), since there is no prior session for it to disturb. Both the
    // eventual bearer commit and the secret/generation rotation happen only
    // when a matching authorization is later redeemed by authorization-
    // bearing Begin.
    final deviceID = normalizedID(request.deviceID);
    final bearerToken = _randomToken();
    final binding = _bindings[deviceID];
    if (binding == null) {
      _bindings[deviceID] = _EmulatedBinding(
        bearerToken: bearerToken,
        deviceSecret: null,
        generation: 0,
      );
    }
    final grant = _EmulatedAuthorization(
      token: _randomToken(),
      deviceID: deviceID,
      generation: binding?.generation ?? 0,
      sessionBearer: bearerToken,
      priorBearer: binding?.bearerToken,
      expiresAt: _clock().add(_authorizationLifetime),
    );
    _authorizations[grant.token] = grant;
    return SyncSuccess(
      VerifyDeviceBindingResponse(
        accessToken: bearerToken,
        bindingAuthorization: grant.token,
        authorizationExpiresAt: grant.expiresAt,
      ),
    );
  }

  SyncFailure<T>? _gate<T>(SyncCredential credential) {
    final deviceID = _deviceIDOf(credential);
    final binding = _bindings[deviceID];
    if (binding == null) return null;
    if (binding.retired) {
      return DeviceRetired<T>(message: 'Device $deviceID is retired.');
    }
    if (binding.bearerExpired ||
        _bearerTokenOf(credential) != binding.bearerToken) {
      return CredentialExpired<T>(message: 'Bearer for $deviceID is expired.');
    }
    if (credential is! BoundDeviceCredential ||
        credential._deviceSecret != binding.deviceSecret) {
      return DeviceAuthorizationRequired<T>(
        message: 'Device $deviceID requires binding authorization.',
      );
    }
    return null;
  }

  Future<SyncOutcome<ReconcileResponse>> _authorizedBegin(
    SyncCredential credential,
    String authorization,
  ) async {
    final deviceID = _deviceIDOf(credential);
    final binding = _bindings[deviceID];
    if (binding == null) {
      return const DeviceAuthorizationRequired<ReconcileResponse>(
        message: 'Device binding is unknown.',
      );
    }
    final grant = _authorizations[authorization];
    if (grant == null ||
        grant.consumed ||
        grant.deviceID != deviceID ||
        grant.generation != binding.generation ||
        grant.sessionBearer != _bearerTokenOf(credential) ||
        (grant.priorBearer != null &&
            grant.priorBearer != binding.bearerToken) ||
        !_clock().isBefore(grant.expiresAt)) {
      return const DeviceAuthorizationRequired<ReconcileResponse>(
        message: 'Binding authorization is invalid or expired.',
      );
    }
    grant.consumed = true;
    final deviceSecret = _randomToken();
    binding
      ..bearerToken = grant.sessionBearer
      ..bearerExpired = false
      ..deviceSecret = deviceSecret
      ..generation += 1
      ..retired = false;
    return SyncSuccess(_boundContext(deviceID, deviceSecret));
  }

  ReconcileResponse _boundContext(String deviceID, String? deviceSecret) {
    final binding = _bindings[deviceID]!;
    final context = ReconciliationContext(
      reconciliationID: 'recon-${++_sequence}',
      snapshotWatermark: 'watermark-$_sequence',
      expiresAt: _clock().add(const Duration(hours: 1)),
    );
    return ReconcileResponse(<String, Object?>{
      'protocol_major': syncOperationMajor,
      'reconciliation': context.toWireJson(),
      'generation': binding.generation,
      if (deviceSecret != null) 'device_secret': deviceSecret,
    });
  }

  String _deviceIDOf(SyncCredential credential) => switch (credential) {
        DeviceCredential(deviceID: final deviceID) => normalizedID(deviceID),
        BoundDeviceCredential(deviceID: final deviceID) =>
          normalizedID(deviceID),
      };

  String _bearerTokenOf(SyncCredential credential) => switch (credential) {
        DeviceCredential(:final _bearerToken) => _bearerToken,
        BoundDeviceCredential(:final _bearerToken) => _bearerToken,
      };

  String _randomToken() {
    final random = Random.secure();
    final bytes = <int>[for (var i = 0; i < 32; i++) random.nextInt(256)];
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
