import 'package:domain/domain.dart';

// MARK: - TransferScopeSign
enum TransferScopeSign { gain, loss, neutral }

// MARK: - TransferScope
extension TransferScope on Entry {
  TransferScopeSign transferScopeSign(Set<String> scopeIDs) {
    final sourceIn = scopeIDs.contains(sourceID);
    final destinationIn = scopeIDs.contains(destinationID);
    if (destinationIn && !sourceIn) return TransferScopeSign.gain;
    if (sourceIn && !destinationIn) return TransferScopeSign.loss;
    return TransferScopeSign.neutral;
  }
}
