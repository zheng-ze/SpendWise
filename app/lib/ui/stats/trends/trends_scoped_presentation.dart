import 'package:flutter/foundation.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_whole_period.dart';

const _wholeDisplayedRange = 'Whole displayed range';

@immutable
class TrendsScopedPresentation {
  const TrendsScopedPresentation({
    required this.breakdown,
    required this.header,
    required this.categorySource,
  });

  final TrendsBreakdown breakdown;
  final TrendsBreakdownHeader header;
  final TrendsCategoryDetailSource categorySource;
}

TrendsScopedPresentation resolveTrendsScopedPresentation(
  TrendsReadyBody body,
  TrendsBreakdownScope scope,
) => switch (scope) {
  TrendsBreakdownScope.wholePeriod => _wholePeriodPresentation(body),
  TrendsBreakdownScope.selectedPeriod => _selectedPeriodPresentation(body),
};

TrendsScopedPresentation _wholePeriodPresentation(TrendsReadyBody body) {
  final header = TrendsBreakdownHeader(
    title: body.wholePeriod.header.title,
    range: _wholeDisplayedRange,
    total: body.wholePeriod.header.total,
  );
  return TrendsScopedPresentation(
    breakdown: body.wholePeriod.breakdown,
    header: header,
    categorySource: TrendsCategoryDetailSource.wholePeriod,
  );
}

TrendsScopedPresentation _selectedPeriodPresentation(TrendsReadyBody body) {
  final total = formatSignedMoney(
    body.breakdown.total,
    kind: body.headline.amountKind,
  );
  final header = TrendsBreakdownHeader(
    title: body.wholePeriod.header.title,
    range: body.headline.title,
    total: total,
  );
  return TrendsScopedPresentation(
    breakdown: body.breakdown,
    header: header,
    categorySource: TrendsCategoryDetailSource.selectedPeriod,
  );
}
