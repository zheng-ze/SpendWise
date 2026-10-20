import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/stats/helpers/slices.dart';

// MARK: - AnalysisViewState
class AnalysisViewState {
  const AnalysisViewState({
    required this.kind,
    required this.ledgerState,
    required this.items,
  });

  final CategoryKind kind;
  final LedgerState ledgerState;
  final List<AnalysisItem> items;
}

// MARK: - AnalysisNotifier
class AnalysisNotifier extends AsyncNotifier<AnalysisViewState>
    with LedgerBackedNotifier<AnalysisViewState> {
  AnalysisNotifier(this._kind);

  final CategoryKind _kind;

  late Ledger _ledger;
  late AnalysisCache _cache;

  @override
  Future<AnalysisViewState> build() async {
    final currentLedger = ledger;
    final cache = analysisCache;
    _ledger = currentLedger;
    _cache = cache;
    currentLedger.addListener(_onChanged);
    cache.addListener(_onChanged);
    ref.onDispose(() => currentLedger.removeListener(_onChanged));
    ref.onDispose(() => cache.removeListener(_onChanged));
    await cache.refresh(currentLedger.state);
    return _buildState();
  }

  void _onChanged() {
    unawaited(_cache.refresh(_ledger.state));
    state = AsyncData(_buildState());
  }

  AnalysisViewState _buildState() {
    return AnalysisViewState(
      kind: _kind,
      ledgerState: _ledger.state,
      items: _cache.items,
    );
  }
}

// MARK: - Constants
final analysisViewModelProvider =
    AsyncNotifierProvider.family<
      AnalysisNotifier,
      AnalysisViewState,
      CategoryKind
    >(AnalysisNotifier.new);

// MARK: - Helpers
List<Slice> analysisSlices(AnalysisViewState state, DateRange window) =>
    slices(state.items, state.kind, window, state.ledgerState);
