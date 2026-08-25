import 'package:flutter/services.dart';

/// Feature-readiness states the native side reports for Foundation Models,
/// mirrored from `SystemLanguageModel.Availability`'s cases. The Swift
/// handler and this enum's declaration order must stay in step, since the
/// channel sends the status as a raw int.
enum FoundationModelsFeatureStatus { unavailable, available }

/// Calls this app's own Swift code to check whether Apple's Foundation
/// Models framework can run on this device and to run one prompt through
/// it. A failure on the native side surfaces as a [PlatformException] from
/// either method, uncaught.
class FoundationModelsChannel {
  static const _channel = MethodChannel(
    'spendwise/foundation_models_field_extractor',
  );

  Future<FoundationModelsFeatureStatus> checkFeatureStatus() async {
    final status = await _channel.invokeMethod<int>('checkFeatureStatus');
    if (status == null) return FoundationModelsFeatureStatus.unavailable;
    return FoundationModelsFeatureStatus.values[status];
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
