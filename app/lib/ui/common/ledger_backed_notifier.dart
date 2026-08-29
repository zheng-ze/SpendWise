import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';

/// Shared shape for an `AsyncNotifier<ViewState>` backed by the app's one
/// [Ledger], with a state update that no-ops once the provider is gone.
mixin LedgerBackedNotifier<T> on AsyncNotifier<T> {
  Ledger get ledger {
    final current = ref.watch(ledgerProvider);
    if (current == null) {
      throw StateError('$runtimeType requires a ready ledger.');
    }
    return current;
  }

  void updateState(T Function(T current) apply) {
    // Guards a picker callback that resolves after its sheet is dismissed.
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(apply(current));
  }
}
