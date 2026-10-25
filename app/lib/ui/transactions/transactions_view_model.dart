import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/shell/shell_providers.dart' show startOfMonthUtc;
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';

// MARK: - TransactionsScreenMode
enum TransactionsScreenMode { daily, monthly }

// MARK: - Steps
sealed class TransactionsStep {}

class EntryFormRequested extends TransactionsStep {
  EntryFormRequested(this.entry);

  final Entry entry;
}

class HistoryTrendsRequested extends TransactionsStep {}

class PickSourceRequested extends TransactionsStep {}

class PickDestinationRequested extends TransactionsStep {}

class PickCategoryRequested extends TransactionsStep {}

class PickRecurrenceRequested extends TransactionsStep {}

class PickDateRequested extends TransactionsStep {}

class PickEndDateRequested extends TransactionsStep {}

class PickEndsRequested extends TransactionsStep {}

class PickReceiptRequested extends TransactionsStep {}

class DocumentCropRequested extends TransactionsStep {
  DocumentCropRequested(this.imageBytes);

  final Uint8List imageBytes;
}

// MARK: - TransactionsViewState
class TransactionsViewState
    implements HasStep<TransactionsViewState, TransactionsStep> {
  const TransactionsViewState({
    required this.title,
    required this.selectedDate,
    required this.daySections,
    required this.income,
    required this.expenses,
    this.step,
  });

  final String title;
  final DateTime selectedDate;
  final List<DaySection> daySections;
  final Decimal income;
  final Decimal expenses;
  @override
  final TransactionsStep? step;

  Decimal get total => income - expenses;

  TransactionsViewState copyWith({
    DateTime? selectedDate,
    List<DaySection>? daySections,
    Decimal? income,
    Decimal? expenses,
    TransactionsStep? Function()? step,
  }) {
    return TransactionsViewState(
      title: title,
      selectedDate: selectedDate ?? this.selectedDate,
      daySections: daySections ?? this.daySections,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      step: step == null ? this.step : step(),
    );
  }

  @override
  TransactionsViewState withStep(TransactionsStep? Function() step) =>
      copyWith(step: step);
}

// MARK: - TransactionsViewModel
abstract class TransactionsViewModel {
  void setDate(DateTime date);
  Future<void> deleteEntry(String id);
  void openEntry(String id);
  void requestTrends();
  void clearStep();
}

// MARK: - TransactionsNotifier
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
      selectedDate: startOfMonthUtc(DateTime.now()),
    );
  }

  void _onLedgerChanged() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      _buildState(
        ledger,
        selectedDate: current.selectedDate,
        step: current.step,
      ),
    );
  }

  TransactionsViewState _buildState(
    Ledger ledger, {
    required DateTime selectedDate,
    TransactionsStep? step,
  }) {
    final ledgerState = ledger.state;
    final sections = daySections(
      ledgerState.entries.values,
      ledgerState,
      interval: monthWindow(selectedDate),
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
      selectedDate: selectedDate,
      daySections: sections,
      income: income,
      expenses: expenses,
      step: step,
    );
  }

  @override
  void setDate(DateTime date) {
    final current = state.value;
    if (current == null) return;
    updateState((_) => _buildState(ledger, selectedDate: date));
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
  void requestTrends() => emitStep(HistoryTrendsRequested());
}

// MARK: - Constants
final transactionsViewModelProvider =
    AsyncNotifierProvider.family<
      TransactionsNotifier,
      TransactionsViewState,
      TransactionsScope?
    >(TransactionsNotifier.new);
