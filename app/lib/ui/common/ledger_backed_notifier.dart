import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ledger/ledger_session.dart';

mixin LedgerBackedNotifier<T> on AsyncNotifier<T> {
  LedgerSession get _session {
    final current = ref.watch(ledgerSessionProvider);
    if (current == null) {
      throw StateError('$runtimeType requires a ready ledger.');
    }
    return current;
  }

  Ledger get ledger => _session.ledger;

  AnalysisCache get analysisCache => _session.analysisCache;

  void updateState(T Function(T current) apply) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(apply(current));
  }
}
