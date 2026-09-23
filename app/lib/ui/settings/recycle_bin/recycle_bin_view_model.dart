import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/format/color_hex.dart';

enum BinRowKind { account, pocket, category }

class BinRow {
  const BinRow({
    required this.kind,
    required this.id,
    required this.name,
    required this.referenceCount,
    this.symbolName,
    this.color,
  });

  final BinRowKind kind;
  final String id;
  final String name;
  final int referenceCount;
  final String? symbolName;
  final Color? color;
}

List<BinRow> _sortedArchivedRows<T>(
  Iterable<T> source,
  bool Function(T item) isArchived,
  BinRow Function(T item) toRow,
) {
  final rows = source.where(isArchived).map(toRow).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return rows;
}

List<BinRow> _accountRows(LedgerState state) => _sortedArchivedRows(
  state.moneySources.values.map((source) => source.asAccount).nonNulls,
  (account) => account.lifecycle == LifecycleState.archived,
  (account) => BinRow(
    kind: BinRowKind.account,
    id: account.id,
    name: account.name,
    referenceCount: state.entriesReferencing(account.id),
  ),
);

List<BinRow> _pocketRows(LedgerState state) => _sortedArchivedRows(
  state.moneySources.values.map((source) => source.asPocket).nonNulls,
  (pocket) => pocket.lifecycle == LifecycleState.archived,
  (pocket) => BinRow(
    kind: BinRowKind.pocket,
    id: pocket.id,
    name: state.sourceName(pocket.id) ?? pocket.name,
    referenceCount: state.entriesReferencing(pocket.id),
  ),
);

List<BinRow> _categoryRows(LedgerState state) => _sortedArchivedRows(
  state.categories.values,
  (category) => category.lifecycle == LifecycleState.archived,
  (category) => BinRow(
    kind: BinRowKind.category,
    id: category.id,
    name: category.name,
    referenceCount: state.entryCountReferencing(category.id),
    symbolName: category.symbol,
    color: parseColorHex(category.colorHex),
  ),
);

sealed class RecycleBinStep {}

class PurgeConfirmationRequested extends RecycleBinStep {
  PurgeConfirmationRequested(this.row);

  final BinRow row;
}

class RecycleBinViewState
    implements HasStep<RecycleBinViewState, RecycleBinStep> {
  const RecycleBinViewState({
    required this.accounts,
    required this.pockets,
    required this.categories,
    this.step,
  });

  final List<BinRow> accounts;
  final List<BinRow> pockets;
  final List<BinRow> categories;
  @override
  final RecycleBinStep? step;

  RecycleBinViewState copyWith({
    List<BinRow>? accounts,
    List<BinRow>? pockets,
    List<BinRow>? categories,
    RecycleBinStep? Function()? step,
  }) {
    return RecycleBinViewState(
      accounts: accounts ?? this.accounts,
      pockets: pockets ?? this.pockets,
      categories: categories ?? this.categories,
      step: step == null ? this.step : step(),
    );
  }

  @override
  RecycleBinViewState withStep(RecycleBinStep? Function() step) =>
      copyWith(step: step);
}

abstract class RecycleBinViewModel {
  void restore(BinRowKind kind, String id);
  void requestPurge(BinRow row);
  void applyPurgeConfirmed(bool confirmed, BinRowKind kind, String id);
  void clearStep();
}

class RecycleBinNotifier extends AsyncNotifier<RecycleBinViewState>
    with
        LedgerBackedNotifier<RecycleBinViewState>,
        StepEmitting<RecycleBinViewState, RecycleBinStep>
    implements RecycleBinViewModel {
  @override
  Future<RecycleBinViewState> build() async {
    final currentLedger = ledger;
    currentLedger.addListener(_onLedgerChanged);
    ref.onDispose(() => currentLedger.removeListener(_onLedgerChanged));
    return _buildState(currentLedger);
  }

  void _onLedgerChanged() {
    final current = state.value;
    state = AsyncData(_buildState(ledger, step: current?.step));
  }

  RecycleBinViewState _buildState(Ledger ledger, {RecycleBinStep? step}) {
    final ledgerState = ledger.state;
    return RecycleBinViewState(
      accounts: _accountRows(ledgerState),
      pockets: _pocketRows(ledgerState),
      categories: _categoryRows(ledgerState),
      step: step,
    );
  }

  @override
  void restore(BinRowKind kind, String id) {
    switch (kind) {
      case BinRowKind.account:
        ledger.restoreAccount(id);
      case BinRowKind.pocket:
        ledger.restorePocket(id);
      case BinRowKind.category:
        ledger.restoreCategory(id);
    }
  }

  @override
  void requestPurge(BinRow row) => emitStep(PurgeConfirmationRequested(row));

  @override
  void applyPurgeConfirmed(bool confirmed, BinRowKind kind, String id) {
    if (confirmed) {
      switch (kind) {
        case BinRowKind.account:
          ledger.purgeAccount(id);
        case BinRowKind.pocket:
          ledger.purgePocket(id);
        case BinRowKind.category:
          ledger.purgeCategory(id);
      }
    }
    clearStep();
  }
}

final recycleBinViewModelProvider =
    AsyncNotifierProvider<RecycleBinNotifier, RecycleBinViewState>(
      RecycleBinNotifier.new,
    );
