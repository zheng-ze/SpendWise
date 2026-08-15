import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/shell/shell_providers.dart';

enum TransactionsScreenMode { daily, monthly }

@immutable
class TransactionsScreenState {
  const TransactionsScreenState({
    required this.selectedDate,
    required this.mode,
  });

  final DateTime selectedDate;
  final TransactionsScreenMode mode;

  TransactionsScreenState copyWith({
    DateTime? selectedDate,
    TransactionsScreenMode? mode,
  }) {
    return TransactionsScreenState(
      selectedDate: selectedDate ?? this.selectedDate,
      mode: mode ?? this.mode,
    );
  }
}

/// One controller per optional source scope, so the unscoped Transactions
/// tab and any account-scoped rendering of this screen each keep their own
/// selected date and mode.
class TransactionsScreenController extends Notifier<TransactionsScreenState> {
  TransactionsScreenController(this.sourceScope);

  final String? sourceScope;

  @override
  TransactionsScreenState build() {
    return TransactionsScreenState(
      selectedDate: startOfMonthUtc(DateTime.now()),
      mode: TransactionsScreenMode.daily,
    );
  }

  void setDate(DateTime date) => state = state.copyWith(selectedDate: date);

  void setMode(TransactionsScreenMode mode) =>
      state = state.copyWith(mode: mode);

  /// Named so the monthly view can call in directly rather than composing
  /// `setMode` and `setDate` itself and risking the two get out of step.
  void switchToDaily(DateTime month) {
    state = TransactionsScreenState(
      selectedDate: month,
      mode: TransactionsScreenMode.daily,
    );
  }
}

final transactionsScreenProvider =
    NotifierProvider.family<
      TransactionsScreenController,
      TransactionsScreenState,
      String?
    >(TransactionsScreenController.new);
