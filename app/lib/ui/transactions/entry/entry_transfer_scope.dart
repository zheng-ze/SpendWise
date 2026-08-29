import 'package:domain/domain.dart';

/// How a transfer reads against one scope: money leaving it, entering it, or
/// staying put (both ends in scope, or neither).
enum TransferScopeSign { gain, loss, neutral }

extension TransferScope on Entry {
  /// Only meaningful for a transfer entry, since a non-transfer has no
  /// destination to weigh against the source.
  TransferScopeSign transferScopeSign(Set<String> scopeIDs) {
    final sourceIn = scopeIDs.contains(sourceID);
    final destinationIn = scopeIDs.contains(destinationID);
    if (destinationIn && !sourceIn) return TransferScopeSign.gain;
    if (sourceIn && !destinationIn) return TransferScopeSign.loss;
    return TransferScopeSign.neutral;
  }
}
