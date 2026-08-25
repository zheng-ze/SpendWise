import 'foundation_models_channel.dart';

/// Runs one prompt through Apple's Foundation Models framework and returns
/// its text response. The native side owns opening and releasing
/// resources, so no separate close.
abstract class FoundationModelsEngine {
  Future<String> runInference(String prompt);
}

/// Runs inference through [FoundationModelsChannel], this app's own
/// hand-rolled platform channel to Swift code calling Apple's
/// `FoundationModels` framework directly.
class ChannelFoundationModelsEngine implements FoundationModelsEngine {
  ChannelFoundationModelsEngine({FoundationModelsChannel? channel})
    : _channel = channel ?? FoundationModelsChannel();

  final FoundationModelsChannel _channel;

  @override
  Future<String> runInference(String prompt) => _channel.runInference(prompt);
}
