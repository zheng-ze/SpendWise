import 'package:flutter/services.dart';

// MARK: - Scanner

class DocumentScannerChannel {
  DocumentScannerChannel(String channelName)
    : _channel = MethodChannel(channelName);

  final MethodChannel _channel;

  // MARK: - Scanning

  Future<Uint8List?> scanDocument() {
    return _channel.invokeMethod<Uint8List>('scanDocument');
  }

  // MARK: - Availability

  Future<bool> isAvailable() async {
    final available = await _channel.invokeMethod<bool>('isAvailable');
    return available ?? false;
  }
}
