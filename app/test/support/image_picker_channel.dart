import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');

void mockImagePickerResult({String? path, String? errorCode}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_imagePickerChannel, (call) async {
    if (errorCode != null) throw PlatformException(code: errorCode);
    return path;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(_imagePickerChannel, null),
  );
}
