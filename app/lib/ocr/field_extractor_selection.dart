import 'android/nano_channel.dart';
import 'android/nano_field_extractor.dart';
import 'field_extractor.dart';
import 'ios/foundation_models_field_extractor.dart';

/// Picks the field extractor for the current platform, or null if none is
/// eligible right now. Each platform's own eligibility check and engine are
/// swapped in independently, so overriding one for a test never has to fake
/// the other two:
/// - [isNanoEligible] fixes Android's AICore/Gemini Nano check.
/// - [isFoundationModelsEligible] fixes iOS's Foundation Models check.
Future<FieldExtractor?> selectFieldExtractor({
  bool? isIOS,
  Future<bool> Function()? isNanoEligible,
  Future<bool> Function()? isFoundationModelsEligible,
}) async {
  if (isIOS ?? defaultTargetPlatform == TargetPlatform.iOS) {
    final eligible = await (isFoundationModelsEligible ?? isFoundationModelsAvailable)();
    return eligible ? FoundationModelsFieldExtractor() : null;
  }

  final eligible = await (isNanoEligible ?? _isNanoAvailable)();
  return eligible ? NanoFieldExtractor() : null;
}

Future<bool> _isNanoAvailable() async {
  final status = await NanoChannel().checkFeatureStatus();
  // Downloadable/downloading means Nano isn't ready to run yet - treated the
  // same as unavailable, since triggering and awaiting that download isn't built.
  return status == NanoFeatureStatus.available;
}
