import 'package:domain/domain.dart';

enum TransferScopeSign { gain, loss, neutral }

extension TransferScope on Entry {
  TransferScopeSign transferScopeSign(Set<String> scopeIDs) {
    final sourceIn = scopeIDs.contains(sourceID);
    final destinationIn = scopeIDs.contains(destinationID);
    if (destinationIn && !sourceIn) return TransferScopeSign.gain;
    if (sourceIn && !destinationIn) return TransferScopeSign.loss;
    return TransferScopeSign.neutral;
  }
}
