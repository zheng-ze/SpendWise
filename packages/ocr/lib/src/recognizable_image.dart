import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Already-decoded image bytes (PNG/JPEG), never a platform file or path.
/// Converting whatever a camera or picker plugin returns is the caller's job.
@immutable
class RecognizableImage {
  const RecognizableImage(this.bytes);

  final Uint8List bytes;

  @override
  bool operator ==(Object other) {
    return other is RecognizableImage && _bytesEqual(other.bytes, bytes);
  }

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => 'RecognizableImage(${bytes.length} bytes)';
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
