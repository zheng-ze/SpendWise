import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/shell/shell_providers.dart' show startOfMonthUtc;
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/monthly/month_summaries.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

enum TransactionsScreenMode { daily, monthly }

sealed class TransactionsStep {}

class EntryFormRequested extends TransactionsStep {
  EntryFormRequested(this.entry);

  final Entry? entry;
}

class PickSourceRequested extends TransactionsStep {}

class PickDestinationRequested extends TransactionsStep {}

class PickCategoryRequested extends TransactionsStep {}

class PickRecurrenceRequested extends TransactionsStep {}

class PickDateRequested extends TransactionsStep {}

class PickEndDateRequested extends TransactionsStep {}

class DocumentCropRequested extends TransactionsStep {
  DocumentCropRequested(this.imageBytes);

  final Uint8List imageBytes;
}

class SourceEditRequested extends TransactionsStep {}

class TransactionsViewState
    implements HasStep<TransactionsViewState, TransactionsStep> {
  const TransactionsViewState({
    required this.title,
    required this.mode,
    required this.selectedDate,
    required this.daySections,
    required this.monthSummaries,
    required this.income,
    required this.expenses,
    required this.showEditSourceAction,
    this.step,
  });

  final String title;
  final TransactionsScreenMode mode;
  final DateTime selectedDate;
  final List<DaySection> daySections;
  final List<MonthSummary> monthSummaries;
  final Decimal income;
  final Decimal expenses;
  final bool showEditSourceAction;
  @override
  final TransactionsStep? step;

  Decimal get total => income - expenses;

  TransactionsViewState copyWith({
    TransactionsScreenMode? mode,
    DateTime? selectedDate,
    List<DaySection>? daySections,
    List<MonthSummary>? monthSummaries,
    Decimal? income,
    Decimal? expenses,
    TransactionsStep? Function()? step,
  }) {
    return TransactionsViewState(
      title: title,
      mode: mode ?? this.mode,
      selectedDate: selectedDate ?? this.selectedDate,
      daySections: daySections ?? this.daySections,
      monthSummaries: monthSummaries ?? this.monthSummaries,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      showEditSourceAction: showEditSourceAction,
      step: step == null ? this.step : step(),
    );
  }

  @override
  TransactionsViewState withStep(TransactionsStep? Function() step) =>
      copyWith(step: step);
}

abstract class TransactionsViewModel {
  void setDate(DateTime date);
  void setMode(TransactionsScreenMode mode);
  Future<void> deleteEntry(String id);
  void switchToDaily(DateTime month);
  void openEntry(String id);
  void requestNewEntry();
  void requestEditSource();
  void clearStep();
}

class TransactionsNotifier extends AsyncNotifier<TransactionsViewState>
    with
        LedgerBackedNotifier<TransactionsViewState>,
        StepEmitting<TransactionsViewState, TransactionsStep>
    implements TransactionsViewModel {
  TransactionsNotifier(this.scope);

  final TransactionsScope? scope;

  Set<String>? get _scopeIDs => scope?.scopeIDs;

  @override
  Future<TransactionsViewState> build() async {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _buildState(
      currentLedger,
      mode: TransactionsScreenMode.daily,
      selectedDate: startOfMonthUtc(DateTime.now()),
    );
  }

  void _onLedgerChanged() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      _buildState(
        ledger,
        mode: current.mode,
        selectedDate: current.selectedDate,
        step: current.step,
      ),
    );
  }

  TransactionsViewState _buildState(
    Ledger ledger, {
    required TransactionsScreenMode mode,
    required DateTime selectedDate,
    TransactionsStep? step,
  }) {
    final ledgerState = ledger.state;
    final interval = mode == TransactionsScreenMode.daily
        ? monthWindow(selectedDate)
        : yearWindow(selectedDate);

    final sections = daySections(
      ledgerState.entries.values,
      ledgerState,
      interval: interval,
      sourceScope: _scopeIDs,
    );

    var income = Decimal.zero;
    var expenses = Decimal.zero;
    for (final section in sections) {
      income += section.income;
      expenses += section.expenses;
    }

    return TransactionsViewState(
      title: scope?.title ?? 'Transactions',
      mode: mode,
      selectedDate: selectedDate,
      daySections: sections,
      monthSummaries: monthSummaries(ledgerState, selectedDate),
      income: income,
      expenses: expenses,
      showEditSourceAction: scope != null,
      step: step,
    );
  }

  @override
  void setDate(DateTime date) {
    final current = state.value;
    if (current == null) return;
    updateState(
      (_) => _buildState(ledger, mode: current.mode, selectedDate: date),
    );
  }

  @override
  void setMode(TransactionsScreenMode mode) {
    final current = state.value;
    if (current == null) return;
    updateState(
      (_) =>
          _buildState(ledger, mode: mode, selectedDate: current.selectedDate),
    );
  }

  @override
  void switchToDaily(DateTime month) {
    updateState(
      (_) => _buildState(
        ledger,
        mode: TransactionsScreenMode.daily,
        selectedDate: month,
      ),
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    ledger.deleteEntry(id);
  }

  @override
  void openEntry(String id) {
    final entry = ledger.state.entries[id];
    if (entry == null) return;
    emitStep(EntryFormRequested(entry));
  }

  @override
  void requestNewEntry() => emitStep(EntryFormRequested(null));

  @override
  void requestEditSource() {
    if (scope == null) return;
    emitStep(SourceEditRequested());
  }
}

final transactionsViewModelProvider =
    AsyncNotifierProvider.family<
      TransactionsNotifier,
      TransactionsViewState,
      TransactionsScope?
    >(TransactionsNotifier.new);
