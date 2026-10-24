import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/summaries/register.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/format/analysis_bucket_name.dart';
import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/stats/helpers/stats_window.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/transactions/top_categories_view_state.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

const _uncategorizedSymbol = 'help_outline';
const _syntheticTransferSymbol = 'swap_horiz';
const _maximumRows = 3;

class TopCategoriesKey {
  const TopCategoriesKey._({required this.period, required this.mode});

  factory TopCategoriesKey.forHistory({
    required DateTime selectedDate,
    required TransactionsScreenMode mode,
  }) => TopCategoriesKey._(
    period: switch (mode) {
      TransactionsScreenMode.daily => DateTime.utc(
        selectedDate.year,
        selectedDate.month,
        1,
      ),
      TransactionsScreenMode.monthly => DateTime.utc(selectedDate.year, 1, 1),
    },
    mode: mode,
  );

  final DateTime period;
  final TransactionsScreenMode mode;

  @override
  bool operator ==(Object other) =>
      other is TopCategoriesKey && other.period == period && other.mode == mode;

  @override
  int get hashCode => Object.hash(period, mode);
}

abstract class TopCategoriesViewModel {
  void retry();
}

class TopCategoriesNotifier extends AsyncNotifier<TopCategoriesViewState>
    with LedgerBackedNotifier<TopCategoriesViewState>
    implements TopCategoriesViewModel {
  TopCategoriesNotifier(this.key);

  final TopCategoriesKey key;

  @override
  TopCategoriesViewState build() {
    final queries = ref.watch(analysisQueriesProvider);
    final session = ref.watch(ledgerSessionProvider);
    if (queries == null || session == null) return _loadingState;

    final currentLedger = session.ledger;
    final revision = currentLedger.revision;
    final window = _windowFor(key);
    final breakdown = queries.readCategoryBreakdown(
      period: key.period,
      mode: _queryMode(key.mode),
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    final register = queries.readRegisterDays(window: window);
    if (_isFailed(breakdown, register)) return _errorState;
    if (!_isCurrent(breakdown, revision) || !_isCurrent(register, revision)) {
      return _loadingState;
    }

    final value = breakdown.value!;
    if (!_matchesWindow(value, window)) return _errorState;
    if (register.value!.isEmpty ||
        (value.total == Decimal.zero && value.rows.isEmpty)) {
      return _compactState;
    }

    final categories = currentLedger.state.categories;
    final rows = value.rows
        .take(_maximumRows)
        .map((row) => _projectRow(row, categories));
    return TopCategoriesViewState(
      body: TopCategoriesReadyBody(
        total: value.total,
        sourceRevision: revision,
        rows: rows.toList(growable: false),
      ),
    );
  }

  @override
  void retry() {
    if (!ref.mounted) return;
    ref.read(analysisQueriesProvider)?.retry();
  }
}

TopCategoryRow _projectRow(
  BreakdownRow row,
  Map<String, TransactionCategory> categories,
) {
  final category = row.bucketID == null ? null : categories[row.bucketID];
  final synthetic =
      row.bucketID != null &&
      syntheticTransferExpenseAccountType(row.bucketID!) != null;
  final name = category?.name ?? analysisBucketName(row.bucketID);
  final symbol =
      category?.symbol ??
      (synthetic ? _syntheticTransferSymbol : _uncategorizedSymbol);
  final color = category == null
      ? colorHexFallback
      : parseColorHex(category.colorHex);
  return TopCategoryRow(
    bucketID: row.bucketID,
    name: name,
    icon: symbolIcon(symbol),
    color: color,
    amount: row.amount,
    sharePercent: row.sharePercent,
  );
}

bool _isFailed(
  AnalysisQueryResult<PeriodBreakdown> breakdown,
  AnalysisQueryResult<List<RegisterDay>> register,
) =>
    breakdown.state == AnalysisQueryState.failed ||
    register.state == AnalysisQueryState.failed;

bool _isCurrent<T>(AnalysisQueryResult<T> result, int revision) =>
    result.state == AnalysisQueryState.ready &&
    result.value != null &&
    result.sourceRevision == revision;

bool _matchesWindow(PeriodBreakdown breakdown, DateRange window) =>
    breakdown.kind == CategoryKind.expense &&
    breakdown.level == BreakdownLevel.categories &&
    breakdown.window.start == window.start &&
    breakdown.window.end == window.end;

DateRange _windowFor(TopCategoriesKey key) => switch (key.mode) {
  TransactionsScreenMode.daily => monthWindow(key.period),
  TransactionsScreenMode.monthly => yearWindow(key.period),
};

AnalysisPeriodMode _queryMode(TransactionsScreenMode mode) => switch (mode) {
  TransactionsScreenMode.daily => AnalysisPeriodMode.month,
  TransactionsScreenMode.monthly => AnalysisPeriodMode.year,
};

const _loadingState = TopCategoriesViewState(body: TopCategoriesLoadingBody());
const _errorState = TopCategoriesViewState(body: TopCategoriesErrorBody());
const _compactState = TopCategoriesViewState(body: TopCategoriesCompactBody());

final topCategoriesViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<TopCategoriesNotifier, TopCategoriesViewState, TopCategoriesKey>(
      TopCategoriesNotifier.new,
    );
