import 'android/nano_channel.dart';
import 'android/nano_field_extractor.dart';
import 'field_extractor.dart';

/// Picks the field extractor for the current device, or null if none is
/// available yet. [isNanoEligible] lets a test fix the eligibility check
/// instead of querying AICore.
Future<FieldExtractor?> selectFieldExtractor({
  Future<bool> Function()? isNanoEligible,
}) async {
  final eligible = await (isNanoEligible ?? _isNanoAvailable)();
  return eligible ? NanoFieldExtractor() : null;
}

Future<bool> _isNanoAvailable() async {
  final status = await NanoChannel().checkFeatureStatus();
  // Downloadable/downloading means Nano isn't ready to run yet - treated the
  // same as unavailable, since triggering and awaiting that download isn't built.
  return status == NanoFeatureStatus.available;
}
