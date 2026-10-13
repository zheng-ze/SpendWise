part of '../../../sync.dart';

// MARK: - Emulated Binding Record

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

// MARK: - Emulated Challenge Record

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

// MARK: - Emulated Authorization Record

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
