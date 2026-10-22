import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/common/base/step_emitting.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_projection.dart';

// MARK: - Step
sealed class TrendsStep {
  const TrendsStep();
}

final class TrendsCategoryDetailRequested extends TrendsStep {
  const TrendsCategoryDetailRequested(this.args);

  final CategoryDetailArgs args;
}

enum TrendsCategoryDetailSource { selectedPeriod, wholePeriod }

// MARK: - ViewState
@immutable
class TrendsViewState implements HasStep<TrendsViewState, TrendsStep> {
  const TrendsViewState({required this.body, this.step});

  final TrendsBody body;
  @override
  final TrendsStep? step;

  @override
  TrendsViewState withStep(TrendsStep? Function() step) =>
      TrendsViewState(body: body, step: step());
}

// MARK: - ViewModel
abstract class TrendsViewModel {
  void setKind(TrendsKind kind);
  void setMode(TrendsMode mode);
  void selectSlot(int index);
  void previousPage();
  void nextPage();
  void retry();
  void setBreakdownScope(TrendsBreakdownScope scope);
  void requestCategoryDetail(
    int rowIndex, {
    TrendsCategoryDetailSource source =
        TrendsCategoryDetailSource.selectedPeriod,
  });
  void clearStep();
}

// MARK: - Notifier
class TrendsNotifier extends AsyncNotifier<TrendsViewState>
    with
        LedgerBackedNotifier<TrendsViewState>,
        StepEmitting<TrendsViewState, TrendsStep>
    implements TrendsViewModel {
  TrendsStep? _step;

  @override
  TrendsViewState build() {
    final readyLedger = ledger;
    final revision = readyLedger.revision;
    final categories = Map<String, TrendsCategory>.unmodifiable({
      for (final category in readyLedger.state.categories.values)
        category.id: (
          name: category.name,
          parentID: category.parentID,
          savedHex: category.colorHex,
        ),
    });
    final preferences = ref.watch(
      displayPreferencesProvider.select(
        (value) => (
          chart: value.breakdownChart,
          level: value.breakdownLevel,
          colours: value.chartColours,
        ),
      ),
    );
    final queries = ref.watch(analysisQueriesProvider);
    if (queries == null) {
      throw StateError('$runtimeType requires analysis queries.');
    }
    final body = projectTrends(
      queries: queries,
      intent: ref.watch(trendsIntentProvider),
      today: ref.watch(todayProvider),
      ledgerRevision: revision,
      categories: categories,
      preferences: preferences,
    );
    return TrendsViewState(body: body, step: _step);
  }

  @override
  void setKind(TrendsKind kind) => _intent.setKind(kind, _context());

  @override
  void setMode(TrendsMode mode) => _intent.setMode(mode, _context());

  @override
  void selectSlot(int index) => _intent.selectSlot(index, _context());

  @override
  void previousPage() => _intent.previousPage(_context());

  @override
  void nextPage() => _intent.nextPage(_context());

  @override
  void retry() => ref.read(analysisQueriesProvider)?.retry();

  @override
  void setBreakdownScope(TrendsBreakdownScope scope) =>
      ref.read(trendsBreakdownScopeProvider.notifier).setScope(scope);

  @override
  void requestCategoryDetail(
    int rowIndex, {
    TrendsCategoryDetailSource source =
        TrendsCategoryDetailSource.selectedPeriod,
  }) {
    if (!ref.mounted) return;
    final body = switch (state) {
      AsyncData(:final value) => value.body,
      _ => null,
    };
    if (body is! TrendsReadyBody) return;
    final rows = switch (source) {
      TrendsCategoryDetailSource.selectedPeriod => body.breakdown.rows,
      TrendsCategoryDetailSource.wholePeriod => body.wholePeriod.breakdown.rows,
    };
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    final target = rows[rowIndex].navigationTarget;
    if (target == null) return;
    final step = TrendsCategoryDetailRequested(target);
    _step = step;
    emitStep(step);
  }

  @override
  void clearStep() {
    _step = null;
    super.clearStep();
  }

  TrendsIntentNotifier get _intent => ref.read(trendsIntentProvider.notifier);

  TrendsContext _context() {
    final bounds = switch (state) {
      AsyncData(:final value) => value.body.bounds,
      _ => null,
    };
    return TrendsContext(
      currentMonth: monthSerial(ref.read(todayProvider)),
      bounds: bounds,
    );
  }
}

final trendsViewModelProvider =
    AsyncNotifierProvider.autoDispose<TrendsNotifier, TrendsViewState>(
      TrendsNotifier.new,
    );
