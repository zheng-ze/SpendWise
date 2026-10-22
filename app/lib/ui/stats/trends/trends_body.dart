import 'package:flutter/foundation.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';

// MARK: - Presentation
@immutable
class TrendsPeriodRow {
  const TrendsPeriodRow({
    required this.rangeLabel,
    required this.previousEnabled,
    required this.nextEnabled,
  });

  final String rangeLabel;
  final bool previousEnabled;
  final bool nextEnabled;
}

@immutable
class TrendsBar {
  const TrendsBar({
    required this.label,
    required this.semanticLabel,
    required this.value,
  });

  final String label;
  final String semanticLabel;
  final double value;
}

@immutable
class TrendsHeadline {
  const TrendsHeadline({
    required this.title,
    required this.sublabel,
    required this.amountKind,
    this.amount,
    this.emptyMessage,
  });

  final String title;
  final String sublabel;
  final AmountKind amountKind;
  final String? amount;
  final String? emptyMessage;
}

@immutable
class TrendsUsual {
  const TrendsUsual({required this.title, required this.body});

  final String title;
  final String body;
}

// MARK: - Body
sealed class TrendsBody {
  const TrendsBody();

  TrendsBounds? get bounds => null;
}

final class TrendsLoadingBody extends TrendsBody {
  const TrendsLoadingBody();
}

final class TrendsErrorBody extends TrendsBody {
  const TrendsErrorBody();
}

final class TrendsEmptyBody extends TrendsBody {
  const TrendsEmptyBody({required this.period, required this.bounds});

  final TrendsPeriodRow period;

  @override
  final TrendsBounds bounds;
}

final class TrendsReadyBody extends TrendsBody {
  const TrendsReadyBody({
    required this.period,
    required this.bars,
    required this.selectedIndex,
    required this.headline,
    required this.usual,
    required this.breakdown,
    required this.bounds,
    this.periodSummary,
  });

  final TrendsPeriodRow period;
  final List<TrendsBar> bars;
  final int selectedIndex;
  final TrendsHeadline headline;
  final TrendsUsual? usual;
  final TrendsBreakdown breakdown;
  final MonthTrendsPeriod? periodSummary;

  @override
  final TrendsBounds bounds;
}
