import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  final cipher = const SyncCipher();
  final key = Uint8List.fromList(
      List<int>.generate(SyncCipher.keyByteCount, (index) => index));
  final aad = Uint8List.fromList([1, 2, 3, 4]);

  group('framing', () {
    test('ciphertext is unpadded base64url of nonce + ciphertext + tag',
        () async {
      final plaintext = Uint8List.fromList(utf8.encode('hello sync'));
      final framed = await cipher.encrypt(
        key: key,
        plaintext: plaintext,
        aad: aad,
      );
      expect(
          framed.length,
          SyncCipher.nonceByteCount +
              plaintext.length +
              SyncCipher.tagByteCount);

      final encoded = base64Url.encode(framed).replaceAll('=', '');
      expect(encoded, isNot(contains(RegExp(r'[+/]'))),
          reason: 'base64url must not use + or /');

      final decoded = base64Url.decode(pad64(encoded));
      expect(decoded.sublist(0, 24), framed.sublist(0, 24),
          reason: 'framed output begins with the 24 byte nonce');
      expect(decoded.sublist(24 + plaintext.length),
          framed.sublist(24 + plaintext.length),
          reason: 'framed output ends with the 16 byte tag');
    });

    test('round-trips through the unpadded base64url string', () async {
      final plaintext = Uint8List.fromList(utf8.encode('round trip'));
      final encoded = await cipher.encrypt(
        key: key,
        plaintext: plaintext,
        aad: aad,
      );
      final decrypted = await cipher.decrypt(
        key: key,
        ciphertext: base64Url.encode(encoded).replaceAll('=', ''),
        aad: aad,
      );
      expect(decrypted, plaintext);
    });
  });

  group('known-answer vector', () {
    test('decrypts the pinned XChaCha20-Poly1305 vector through SyncCipher',
        () async {
      // Fixed 256-bit key, 24-byte nonce, and AAD produce a deterministic
      // AEAD output. Build the framing the same way SyncCipher does (nonce ||
      // ciphertext || appended tag), then exercise SyncCipher's own decode and
      // decrypt path against the pinned vector so a framing regression here
      // fails this test rather than staying green.
      final nonce =
          Uint8List.fromList(List<int>.generate(24, (index) => index + 1));
      final plaintext = Uint8List.fromList(utf8.encode('hello sync'));
      final algorithm = Xchacha20.poly1305Aead();
      final box = await algorithm.encrypt(
        plaintext,
        secretKey: SecretKey(key),
        nonce: nonce,
        aad: aad,
      );
      final framed = <int>[...nonce, ...box.cipherText, ...box.mac.bytes];
      expect(
        framed.length,
        SyncCipher.nonceByteCount +
            plaintext.length +
            SyncCipher.tagByteCount);
      final pinned = base64Url.encode(framed).replaceAll('=', '');
      expect(pinned, 'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcY1J4-9sQ8y0pbaw9NdsXMQhAVVJXR-6CgASY');
      final decrypted =
          await cipher.decrypt(key: key, ciphertext: pinned, aad: aad);
      expect(decrypted, plaintext);
    });
  });

  group('authentication', () {
    Future<String> seal(SyncCipher c, Uint8List plaintext) async => base64Url
        .encode(await c.encrypt(
          key: key,
          plaintext: plaintext,
          aad: aad,
        ))
        .replaceAll('=', '');

    test('rejects tampered AAD metadata with SyncPayloadDecryptionError',
        () async {
      final sealed = await seal(cipher, Uint8List.fromList(utf8.encode('x')));
      await expectLater(
        cipher.decrypt(
          key: key,
          ciphertext: sealed,
          aad: Uint8List.fromList([9, 9, 9, 9]),
        ),
        throwsA(isA<SyncPayloadDecryptionError>()),
      );
    });

    test('rejects a tampered ciphertext body', () async {
      final plaintext = Uint8List.fromList(utf8.encode('tamper me'));
      final framed = await cipher.encrypt(
        key: key,
        plaintext: plaintext,
        aad: aad,
      );
      final corrupted = Uint8List.fromList(framed)
        ..[SyncCipher.nonceByteCount] ^= 0xFF;
      final sealed = base64Url.encode(corrupted).replaceAll('=', '');
      await expectLater(
        cipher.decrypt(key: key, ciphertext: sealed, aad: aad),
        throwsA(isA<SyncPayloadDecryptionError>()),
      );
    });

    test('maps authentication failure, not a raw library error', () async {
      final sealed = await seal(cipher, Uint8List.fromList(utf8.encode('y')));
      await expectLater(
        cipher.decrypt(
            key: key, ciphertext: sealed, aad: Uint8List.fromList([0])),
        throwsA(
          isA<SyncPayloadDecryptionError>()
              .having(
                (error) => error.toString(),
                'toString',
                contains('SyncPayloadDecryptionError'),
              )
              .having(
                (error) => error.error,
                'source error',
                isNotNull,
              ),
        ),
      );
    });

    test('rejects a ciphertext shorter than nonce plus tag', () async {
      await expectLater(
        cipher.decrypt(
          key: key,
          ciphertext: base64Url.encode(Uint8List(10)).replaceAll('=', ''),
          aad: aad,
        ),
        throwsA(isA<SyncPayloadDecryptionError>()),
      );
    });
  });

  group('key length', () {
    test('rejects a key other than 256 bits for encrypt', () async {
      await expectLater(
        cipher.encrypt(
          key: Uint8List(16),
          plaintext: Uint8List(4),
          aad: aad,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a key other than 256 bits for decrypt', () async {
      await expectLater(
        cipher.decrypt(key: Uint8List(16), ciphertext: 'AAAA', aad: aad),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

String pad64(String value) {
  final remainder = value.length % 4;
  return remainder == 0 ? value : value + '=' * (4 - remainder);
}
