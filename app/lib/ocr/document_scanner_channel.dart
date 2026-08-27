import 'package:flutter/services.dart';

class DocumentScannerChannel {
  DocumentScannerChannel(String channelName)
    : _channel = MethodChannel(channelName);

  final MethodChannel _channel;

  /// Null means the user backed out of the scanner without capturing.
  Future<Uint8List?> scanDocument() {
    return _channel.invokeMethod<Uint8List>('scanDocument');
  }

  /// True if Google Play Services is installed and current enough to run the
  /// scanner.
  Future<bool> isAvailable() async {
    final available = await _channel.invokeMethod<bool>('isAvailable');
    return available ?? false;
  }
}
