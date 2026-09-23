import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';

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
