import 'package:flutter/services.dart';

class DocumentScannerChannel {
  DocumentScannerChannel(String channelName)
    : _channel = MethodChannel(channelName);

  final MethodChannel _channel;

  Future<Uint8List?> scanDocument() {
    return _channel.invokeMethod<Uint8List>('scanDocument');
  }

  Future<bool> isAvailable() async {
    final available = await _channel.invokeMethod<bool>('isAvailable');
    return available ?? false;
  }
}
