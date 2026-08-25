import 'nano_channel.dart';

/// Runs one prompt through Gemini Nano and returns its text response. The
/// native side owns opening and releasing resources, so no separate close.
abstract class NanoEngine {
  Future<String> runInference(String prompt);
}

/// Runs inference through [NanoChannel], this app's own hand-rolled platform
/// channel to Kotlin code calling the ML Kit GenAI Prompt SDK directly.
class ChannelNanoEngine implements NanoEngine {
  ChannelNanoEngine({NanoChannel? channel}) : _channel = channel ?? NanoChannel();

  final NanoChannel _channel;

  @override
  Future<String> runInference(String prompt) => _channel.runInference(prompt);
}
