import 'package:flutter/services.dart';

/// Feature-readiness states the native side reports for Gemini Nano, mirrored
/// from `com.google.mlkit.genai.common.FeatureStatus`'s int constants. The
/// Kotlin handler and this enum's declaration order must stay in step, since
/// the channel sends the status as a raw int.
enum NanoFeatureStatus { unavailable, downloadable, downloading, available }

/// Calls this app's own Kotlin code to check whether Gemini Nano can run on
/// this device and to run one prompt through it. A failure on the native
/// side surfaces as a [PlatformException] from either method, uncaught.
class NanoChannel {
  static const _channel = MethodChannel('spendwise/nano_field_extractor');

  Future<NanoFeatureStatus> checkFeatureStatus() async {
    final status = await _channel.invokeMethod<int>('checkFeatureStatus');
    if (status == null) return NanoFeatureStatus.unavailable;
    return NanoFeatureStatus.values[status];
  }

  Future<String> runInference(String prompt) async {
    final response = await _channel.invokeMethod<String>('runInference', {
      'prompt': prompt,
    });
    if (response == null) {
      throw PlatformException(
        code: 'runInference',
        message: 'Native side returned no response',
      );
    }
    return response;
  }
}
