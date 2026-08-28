import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';

/// Shared shape for an `AsyncNotifier<ViewState>` backed by the app's one
/// [Ledger]: a ready-or-throw ledger accessor, and a state update that
/// silently no-ops once the provider is gone rather than writing into a
/// disposed notifier — the guard a picker callback needs when it resolves
/// after the user has already dismissed the sheet that launched it.
mixin LedgerBackedNotifier<T> on AsyncNotifier<T> {
  Ledger get ledger {
    final current = ref.watch(ledgerProvider);
    if (current == null) {
      throw StateError('$runtimeType requires a ready ledger.');
    }
    return current;
  }

  void updateState(T Function(T current) apply) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(apply(current));
  }
}
