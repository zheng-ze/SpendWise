import 'dart:isolate';

import 'package:domain/domain.dart';

// MARK: - Runners

typedef ComputeRunner = Future<List<AnalysisItem>> Function(LedgerState state);

Future<List<AnalysisItem>> syncComputeRunner(LedgerState state) async {
  return Accounting.analysisItems(state);
}

Future<List<AnalysisItem>> isolateComputeRunner(LedgerState state) {
  // Must not capture the calling instance; it would not send.
  return Isolate.run(() => Accounting.analysisItems(state));
}
