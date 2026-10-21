import 'package:decimal/decimal.dart';

import 'package:spendwise/ledger/analysis/breakdowns/compared_with_usual.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';

// MARK: - Constants
const _usualTitle = 'Compared with usual';
const _notEnoughDataBody = 'Not enough data';
const _sameAsUsual = 'Same as usual';
const _higher = 'higher';
const _lower = 'lower';
const _percentScale = 1000;
const _tenths = 10;
const _threeMonths = 3;

// MARK: - Usual
TrendsUsual trendsUsual(ComparedWithUsual usual, {required bool currentMonth}) {
  const unavailable = TrendsUsual(title: _usualTitle, body: _notEnoughDataBody);
  final baseline = usual.baselineTotal;
  if (usual.state == ComparedWithUsualState.notEnoughData) return unavailable;
  if (baseline == null || usual.baselineWindows.isEmpty) return unavailable;
  if (baseline == Decimal.zero) {
    return TrendsUsual(
      title: _usualTitle,
      body: 'Usual is ${formatMoney(Decimal.zero)}.',
    );
  }
  return TrendsUsual(
    title: _title(usual.observedTotal, baseline),
    body: _body(usual, currentMonth: currentMonth),
  );
}

String _title(Decimal observed, Decimal baseline) {
  final difference = observed * Decimal.fromInt(_threeMonths) - baseline;
  if (difference == Decimal.zero) return '$_usualTitle: $_sameAsUsual';
  final direction = difference > Decimal.zero ? _higher : _lower;
  return '$_usualTitle: ${_percent(difference.abs(), baseline)}% $direction';
}

String _percent(Decimal difference, Decimal baseline) {
  final ratio = difference * Decimal.fromInt(_percentScale) / baseline;
  final tenths = _halfEvenQuotient(ratio.numerator, ratio.denominator);
  final divisor = BigInt.from(_tenths);
  return '${tenths ~/ divisor}.${tenths % divisor}';
}

BigInt _halfEvenQuotient(BigInt numerator, BigInt denominator) {
  final quotient = numerator ~/ denominator;
  final remainder = numerator - quotient * denominator;
  final comparison = (remainder * BigInt.two).compareTo(denominator);
  final roundUp = comparison > 0 || (comparison == 0 && quotient.isOdd);
  return roundUp ? quotient + BigInt.one : quotient;
}

String _body(ComparedWithUsual usual, {required bool currentMonth}) {
  final mean = formatMoney(usual.usualMean ?? Decimal.zero);
  final windows = usual.baselineWindows;
  final firstStart = windows.first.start;
  final lastStart = windows.last.start;
  final crossesYear = firstStart.year != lastStart.year;
  final format = crossesYear ? formatMonthNameYear : formatMonthName;
  final range = '${format(firstStart)} to ${format(lastStart)}';
  if (!currentMonth) return 'Usual is $mean, the $range average.';
  return 'Usual is $mean, the day 1 to ${usual.elapsedDayCount} average '
      "for $range, clipped to each month's length.";
}
