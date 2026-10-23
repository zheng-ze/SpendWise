import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_args.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_intent.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_projection.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

export 'package:spendwise/ui/stats/category_detail/category_detail_args.dart';
export 'package:spendwise/ui/stats/category_detail/category_detail_body.dart';
export 'package:spendwise/ui/stats/category_detail/category_detail_projection.dart';

abstract class CategoryDetailViewModel {
  void setScope(CategoryScope scope);
  void setTrendMode(TrendsMode mode);
  void previousTrendPage();
  void nextTrendPage();
  void selectTrendSlot(int index);
  void retry();
}

class CategoryDetailIntentNotifier extends Notifier<CategoryDetailIntent> {
  CategoryDetailIntentNotifier(this._args);

  final CategoryDetailArgs _args;

  @override
  CategoryDetailIntent build() => CategoryDetailIntent.initial(_args);

  void setScope(CategoryScope scope) => _replace(state.withScope(scope));

  void setTrendMode(TrendsMode mode, TrendsContext context) =>
      _replace(state.withMode(mode, context));

  void previousTrendPage(TrendsContext context) =>
      _replace(state.previousPage(context));

  void nextTrendPage(TrendsContext context) =>
      _replace(state.nextPage(context));

  void selectTrendSlot(int index, TrendsContext context) =>
      _replace(state.selectSlot(index, context));

  void _replace(CategoryDetailIntent next) {
    if (!identical(next, state)) state = next;
  }
}

final categoryDetailIntentProvider = NotifierProvider.autoDispose
    .family<
      CategoryDetailIntentNotifier,
      CategoryDetailIntent,
      CategoryDetailArgs
    >(CategoryDetailIntentNotifier.new);

class CategoryDetailNotifier extends AsyncNotifier<CategoryDetailViewState>
    implements CategoryDetailViewModel {
  CategoryDetailNotifier(this._args);

  final CategoryDetailArgs _args;

  @override
  CategoryDetailViewState build() {
    final queries = ref.watch(analysisQueriesProvider);
    final session = ref.watch(ledgerSessionProvider);
    final intent = ref.watch(categoryDetailIntentProvider(_args));
    final today = ref.watch(todayProvider);
    if (queries == null || session == null) {
      return categoryDetailUnreadyState(_args, intent.scope);
    }
    final revision = session.ledger.revision;
    final periodResult = queries.readCategoryDetailPeriod(
      mainID: _args.mainID,
      kind: _args.kind,
      scope: categoryDetailAnalysisScope(intent.scope),
      period: _args.initialDate,
      mode: _args.isYearRange
          ? AnalysisPeriodMode.year
          : AnalysisPeriodMode.month,
    );
    final period = periodResult.value;
    final periodIsCurrent =
        periodResult.state == AnalysisQueryState.ready &&
        period != null &&
        periodResult.sourceRevision == revision;
    final effectiveScope = periodIsCurrent
        ? period.scope
        : categoryDetailAnalysisScope(intent.scope);
    final currentMonth = monthSerial(today);
    final bounds = TrendsBounds.fromFirstRecord(
      periodIsCurrent ? period.firstRecord : null,
      currentMonth,
    );
    final context = TrendsContext(currentMonth: currentMonth, bounds: bounds);
    final basis = intent.trend.effective(context);
    final spreadResult = queries.readCategoryDetailSpread(
      mainID: _args.mainID,
      kind: _args.kind,
      scope: effectiveScope,
      endPeriod: _periodFor(basis.end, intent.trend.mode),
      mode: _analysisMode(intent.trend.mode),
      selectedPeriod: intent.hasExplicitSelection
          ? _periodFor(basis.selected, intent.trend.mode)
          : null,
    );
    return projectCategoryDetailWithTrend(
      periodResult: periodResult,
      spreadResult: spreadResult,
      ledgerRevision: revision,
      ledgerState: session.ledger.state,
      args: _args,
      intent: intent,
      trendContext: context,
      basis: basis,
      today: today,
    );
  }

  @override
  void setScope(CategoryScope scope) {
    if (!ref.mounted) return;
    ref.read(categoryDetailIntentProvider(_args).notifier).setScope(scope);
  }

  @override
  void setTrendMode(TrendsMode mode) {
    if (!ref.mounted) return;
    ref
        .read(categoryDetailIntentProvider(_args).notifier)
        .setTrendMode(mode, _context());
  }

  @override
  void previousTrendPage() {
    if (!ref.mounted) return;
    ref
        .read(categoryDetailIntentProvider(_args).notifier)
        .previousTrendPage(_context());
  }

  @override
  void nextTrendPage() {
    if (!ref.mounted) return;
    ref
        .read(categoryDetailIntentProvider(_args).notifier)
        .nextTrendPage(_context());
  }

  @override
  void selectTrendSlot(int index) {
    if (!ref.mounted) return;
    ref
        .read(categoryDetailIntentProvider(_args).notifier)
        .selectTrendSlot(index, _context());
  }

  @override
  void retry() {
    if (!ref.mounted) return;
    ref.read(analysisQueriesProvider)?.retry();
  }

  TrendsContext _context() {
    final current = state.value?.trendContext;
    return current ??
        TrendsContext(currentMonth: monthSerial(ref.read(todayProvider)));
  }
}

DateTime _periodFor(int period, TrendsMode mode) => switch (mode) {
  TrendsMode.month => monthStartOf(period),
  TrendsMode.year => DateTime.utc(period),
};

AnalysisPeriodMode _analysisMode(TrendsMode mode) => switch (mode) {
  TrendsMode.month => AnalysisPeriodMode.month,
  TrendsMode.year => AnalysisPeriodMode.year,
};

final categoryDetailViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<
      CategoryDetailNotifier,
      CategoryDetailViewState,
      CategoryDetailArgs
    >(CategoryDetailNotifier.new);
