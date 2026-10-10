import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';

enum InsightState { available, historyNeeded }

typedef BaselineEvidence = ({
  DateRange window,
  Decimal total,
  int expenseItemCount,
});

typedef BaselineComparison = ({
  Decimal usualMean,
  Decimal difference,
  Decimal? relativeChangePercent,
});

const int baselineWindowCount = 3;

final Decimal _baselineWindowDecimal = Decimal.fromInt(baselineWindowCount);
final Decimal _percentScale = Decimal.fromInt(100);
const int _divisionScale = 12;

class InsightRules {
  InsightRules({
    Decimal? minimumUsual,
    Decimal? minimumAbsoluteChange,
    Decimal? minimumRelativeChange,
    this.minimumExpenseCount = 5,
    this.maximumCategoryChanges = 2,
  }) : minimumUsual = minimumUsual ?? Decimal.fromInt(10),
       minimumAbsoluteChange = minimumAbsoluteChange ?? Decimal.fromInt(20),
       minimumRelativeChange = minimumRelativeChange ?? Decimal.parse('0.20') {
    if (this.minimumUsual <= Decimal.zero) {
      throw ArgumentError.value(minimumUsual, 'minimumUsual', 'Must be > 0.');
    }
    if (this.minimumAbsoluteChange < Decimal.zero ||
        this.minimumRelativeChange < Decimal.zero) {
      throw ArgumentError('Change thresholds must not be negative.');
    }
    if (minimumExpenseCount < 1 || maximumCategoryChanges < 1) {
      throw ArgumentError('Counts must be positive.');
    }
  }

  static final InsightRules defaults = InsightRules();

  final Decimal minimumUsual;

  final Decimal minimumAbsoluteChange;

  final Decimal minimumRelativeChange;

  final int minimumExpenseCount;

  final int maximumCategoryChanges;

  bool qualifies(
    Decimal observedTotal,
    Decimal baselineTotal,
    int baselineExpenseCount,
  ) {
    final change = scaledChange(observedTotal, baselineTotal).abs();
    return change > Decimal.zero &&
        baselineExpenseCount >= minimumExpenseCount &&
        baselineTotal >= minimumUsual * _baselineWindowDecimal &&
        change >= minimumAbsoluteChange * _baselineWindowDecimal &&
        change >= baselineTotal * minimumRelativeChange;
  }
}

Decimal scaledChange(Decimal observedTotal, Decimal baselineTotal) =>
    observedTotal * _baselineWindowDecimal - baselineTotal;

BaselineComparison compareToBaseline(
  Decimal observedTotal,
  Decimal baselineTotal,
) {
  final change = scaledChange(observedTotal, baselineTotal);
  return (
    usualMean: (baselineTotal / _baselineWindowDecimal).toDecimal(
      scaleOnInfinitePrecision: _divisionScale,
    ),
    difference: (change / _baselineWindowDecimal).toDecimal(
      scaleOnInfinitePrecision: _divisionScale,
    ),
    relativeChangePercent: baselineTotal == Decimal.zero
        ? null
        : (_percentScale * change / baselineTotal).toDecimal(
            scaleOnInfinitePrecision: _divisionScale,
          ),
  );
}
