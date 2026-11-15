import 'package:domain/domain.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';

const usualMinimumCompleteMonths = 3;

const _baselineWindowMonths = 11;
const _centsPerUnit = 100;
const _centsScale = -2;

List<DateTime> usualBaselineMonths({
  required DateTime? firstRecordMonth,
  required DateTime today,
}) {
  if (firstRecordMonth == null) return const [];
  final day = startOfDayUtc(today);
  final firstMonth = DateTime.utc(
    firstRecordMonth.year,
    firstRecordMonth.month,
    1,
  );
  final candidates = [
    for (var back = _baselineWindowMonths; back >= 1; back--)
      DateTime.utc(day.year, day.month - back, 1),
  ];
  return [
    for (final month in candidates)
      if (classifyPeriod(
            window: monthWindow(month),
            firstRecordMonth: firstMonth,
            today: day,
          ) ==
          PeriodCompleteness.complete)
        month,
  ];
}

Decimal roundedCents(Decimal numerator, int denominator) {
  final scaled = numerator * Decimal.fromInt(_centsPerUnit);
  final cents = (scaled / Decimal.fromInt(denominator)).round();
  return Decimal.fromBigInt(cents).shift(_centsScale);
}
