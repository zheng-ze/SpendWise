import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/step_emitting.dart';
import 'package:spendwise/ui/stats/helpers/slices.dart';

sealed class AnalysisStep {}

class CategoryDetailRequested extends AnalysisStep {
  CategoryDetailRequested({
    required this.mainID,
    required this.isYearRange,
    required this.initialDate,
  });

  final String mainID;
  final bool isYearRange;
  final DateTime initialDate;
}

class AnalysisViewState implements HasStep<AnalysisViewState, AnalysisStep> {
  const AnalysisViewState({
    required this.kind,
    required this.ledgerState,
    required this.items,
    this.step,
  });

  final CategoryKind kind;
  final LedgerState ledgerState;
  final List<AnalysisItem> items;
  @override
  final AnalysisStep? step;

  AnalysisViewState copyWith({
    LedgerState? ledgerState,
    List<AnalysisItem>? items,
    AnalysisStep? Function()? step,
  }) {
    return AnalysisViewState(
      kind: kind,
      ledgerState: ledgerState ?? this.ledgerState,
      items: items ?? this.items,
      step: step == null ? this.step : step(),
    );
  }

  @override
  AnalysisViewState withStep(AnalysisStep? Function() step) =>
      copyWith(step: step);
}

abstract class AnalysisViewModel {
  void requestCategoryDetail({
    required String mainID,
    required bool isYearRange,
    required DateTime initialDate,
  });
  void clearStep();
}

class AnalysisNotifier extends AsyncNotifier<AnalysisViewState>
    with
        LedgerBackedNotifier<AnalysisViewState>,
        StepEmitting<AnalysisViewState, AnalysisStep>
    implements AnalysisViewModel {
  AnalysisNotifier(this._kind);

  final CategoryKind _kind;

  AnalysisCache get _cache => ref.read(analysisCacheProvider);

  late Ledger _ledger;

  @override
  Future<AnalysisViewState> build() async {
    final currentLedger = ledger;
    final cache = _cache;
    _ledger = currentLedger;
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

  AnalysisViewState _buildState({AnalysisStep? step}) {
    return AnalysisViewState(
      kind: _kind,
      ledgerState: _ledger.state,
      items: _cache.items,
      step: step,
    );
  }

  @override
  void requestCategoryDetail({
    required String mainID,
    required bool isYearRange,
    required DateTime initialDate,
  }) => emitStep(
    CategoryDetailRequested(
      mainID: mainID,
      isYearRange: isYearRange,
      initialDate: initialDate,
    ),
  );
}

final analysisViewModelProvider =
    AsyncNotifierProvider.family<
      AnalysisNotifier,
      AnalysisViewState,
      CategoryKind
    >(AnalysisNotifier.new);

List<Slice> analysisSlices(AnalysisViewState state, DateRange window) =>
    slices(state.items, state.kind, window, state.ledgerState);
