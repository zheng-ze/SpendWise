import 'dart:typed_data';

// MARK: - NativeScannerOutcome
sealed class NativeScannerOutcome {
  const NativeScannerOutcome();
}

// MARK: - NativeScannerUnavailable
class NativeScannerUnavailable extends NativeScannerOutcome {
  const NativeScannerUnavailable();
}

// MARK: - NativeScannerCancelled
class NativeScannerCancelled extends NativeScannerOutcome {
  const NativeScannerCancelled();
}

// MARK: - NativeScannerCaptured
class NativeScannerCaptured extends NativeScannerOutcome {
  const NativeScannerCaptured(this.bytes);

  final Uint8List bytes;
}
