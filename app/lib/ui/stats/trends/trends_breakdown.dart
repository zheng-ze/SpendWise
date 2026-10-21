import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart'
    as analysis;
import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/ui/format/analysis_bucket_name.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

const _shareDigits = 1;
const _directPrefix = 'Direct to ';

typedef TrendsCategory = ({String name, String? parentID, String savedHex});
typedef TrendsBreakdownPreferences = ({
  settings.BreakdownChart chart,
  settings.BreakdownLevel level,
  settings.ChartColours colours,
});
typedef TrendsBreakdownRow = ({
  String? bucketID,
  String? mainBucketID,
  bool isDirect,
  String name,
  String? parentContext,
  String? savedHex,
  Decimal amount,
  Decimal sharePercent,
  String formattedAmount,
  String formattedShare,
  CategoryDetailArgs? navigationTarget,
});

@immutable
class TrendsBreakdown {
  TrendsBreakdown({
    required this.sourceRevision,
    required this.period,
    required this.kind,
    required this.mode,
    required this.preferences,
    required this.total,
    required List<TrendsBreakdownRow> rows,
  }) : rows = List.unmodifiable(rows);

  final int sourceRevision;
  final DateTime period;
  final CategoryKind kind;
  final TrendsMode mode;
  final TrendsBreakdownPreferences preferences;
  final Decimal total;
  final List<TrendsBreakdownRow> rows;

  settings.BreakdownChart get chart => preferences.chart;
  settings.BreakdownLevel get level => preferences.level;
  settings.ChartColours get colours => preferences.colours;
  bool get isEmpty => rows.isEmpty;
}

final class TrendsEmptyBreakdown extends TrendsBreakdown {
  TrendsEmptyBreakdown({
    required super.sourceRevision,
    required super.period,
    required super.kind,
    required super.mode,
    required super.preferences,
  }) : super(total: Decimal.zero, rows: const []);
}

TrendsBreakdownRow projectBreakdownRow(
  analysis.BreakdownRow row, {
  required Map<String, TrendsCategory> categories,
  required DateTime period,
  required TrendsMode mode,
  required CategoryKind kind,
}) {
  final id = row.isDirect ? row.mainBucketID : row.bucketID;
  final synthetic =
      id != null && syntheticTransferExpenseAccountType(id) != null;
  final category = synthetic ? null : categories[id];
  final name = category?.name ?? analysisBucketName(id);
  final parentID = row.isDirect ? row.mainBucketID : category?.parentID;
  final parent = parentID == null
      ? null
      : categories[parentID]?.name ?? uncategorizedName;
  final mainID = row.mainBucketID;
  final navigable =
      mainID != null && syntheticTransferExpenseAccountType(mainID) == null;
  final target = navigable
      ? CategoryDetailArgs(
          mainID: mainID,
          kind: kind,
          isYearRange: mode == TrendsMode.year,
          initialDate: period,
        )
      : null;
  final amountKind = kind == CategoryKind.expense
      ? AmountKind.expense
      : AmountKind.income;
  return (
    bucketID: row.bucketID,
    mainBucketID: mainID,
    isDirect: row.isDirect,
    name: row.isDirect ? '$_directPrefix$name' : name,
    parentContext: parent,
    savedHex: category?.savedHex,
    amount: row.amount,
    sharePercent: row.sharePercent,
    formattedAmount: formatSignedMoney(
      row.amount,
      kind: amountKind,
      symbol: false,
    ),
    formattedShare: '${row.sharePercent.toStringAsFixed(_shareDigits)}%',
    navigationTarget: target,
  );
}
