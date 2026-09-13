part of '../../sync.dart';

/// Package-owned error for AEAD authentication failure during envelope
/// decryption.
///
/// Distinct from a backend [SyncFailure]: decryption and decode failures are
/// thrown rather than returned as a backend outcome.
final class SyncPayloadDecryptionError implements Exception {
  const SyncPayloadDecryptionError(this.message, {this.error});

  final String message;
  final Object? error;

  @override
  String toString() => 'SyncPayloadDecryptionError: $message';
}

/// XChaCha20-Poly1305 AEAD engine for sync envelopes.
///
/// Every encryption call uses a fresh cryptographically random 24-byte nonce
/// and a 256-bit key. The framed ciphertext is unpadded base64url of the 24
/// byte nonce followed by the AEAD ciphertext and its appended 16 byte tag,
/// matching [SyncEnvelope.ciphertext]'s on-the-wire shape.
final class SyncCipher {
  const SyncCipher();

  static const int keyByteCount = 32;
  static const int nonceByteCount = 24;
  static const int tagByteCount = 16;

  Future<Uint8List> encrypt({
    required Uint8List key,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    _assertKeyLength(key);
    final nonce = _randomNonce();
    final cipher = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    final box = await cipher.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );
    return _frame(nonce, box);
  }

  Future<Uint8List> decrypt({
    required Uint8List key,
    required String ciphertext,
    required Uint8List aad,
  }) async {
    _assertKeyLength(key);
    final raw = _decodeBase64Url(ciphertext);
    if (raw.length < nonceByteCount + tagByteCount) {
      throw const SyncPayloadDecryptionError(
        'Ciphertext is shorter than nonce plus tag.',
      );
    }
    final nonce = Uint8List.fromList(raw.sublist(0, nonceByteCount));
    final tag =
        Uint8List.fromList(raw.sublist(raw.length - tagByteCount, raw.length));
    final body = Uint8List.fromList(
        raw.sublist(nonceByteCount, raw.length - tagByteCount));
    final cipher = Xchacha20.poly1305Aead();
    final secretKey = SecretKey(key);
    try {
      final plaintext = await cipher.decrypt(
        SecretBox(body, nonce: nonce, mac: Mac(tag)),
        secretKey: secretKey,
        aad: aad,
      );
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError catch (error) {
      throw SyncPayloadDecryptionError(
        'Envelope authentication failed; metadata or payload is invalid.',
        error: error,
      );
    }
  }

  Uint8List _frame(Uint8List nonce, SecretBox box) =>
      Uint8List.fromList(<int>[...nonce, ...box.cipherText, ...box.mac.bytes]);

  Uint8List _randomNonce() {
    final nonce = Uint8List(nonceByteCount);
    final random = Random.secure();
    for (var index = 0; index < nonceByteCount; index += 1) {
      nonce[index] = random.nextInt(256);
    }
    return nonce;
  }

  Uint8List _decodeBase64Url(String value) {
    final padded = _base64Padding(value);
    return base64Url.decode(padded);
  }

  static String _base64Padding(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value + '=' * (4 - remainder);
  }

  static void _assertKeyLength(Uint8List key) {
    if (key.length != keyByteCount) {
      throw ArgumentError.value(
        key.length,
        'key',
        'E2E key must be $keyByteCount bytes.',
      );
    }
  }
}
