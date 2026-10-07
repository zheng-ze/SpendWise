import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

enum AmountKind { income, expense, transfer }

const _groupSize = 3;

const _keptFractionDigits = 2;

const _inspectedFractionDigits = 3;

const _centsPerUnit = 100;

final NumberFormat _percent = NumberFormat.percentPattern()
  ..maximumFractionDigits = 0;

String _groupedInteger(String digits) {
  final buffer = StringBuffer();
  final offset = digits.length % _groupSize;
  if (offset > 0) buffer.write(digits.substring(0, offset));
  for (var i = offset; i < digits.length; i += _groupSize) {
    if (buffer.isNotEmpty) buffer.write(',');
    buffer.write(digits.substring(i, i + _groupSize));
  }
  if (buffer.isEmpty) buffer.write('0');
  return buffer.toString();
}

String _roundedTwoPlaces(Decimal magnitude, {required bool grouped}) {
  final parts = magnitude.toString().split('.');
  final intPart = parts[0];
  final fraction = (parts.length > 1 ? parts[1] : '').padRight(
    _inspectedFractionDigits,
    '0',
  );
  var kept = int.parse(fraction.substring(0, _keptFractionDigits));
  final rest = fraction.substring(_keptFractionDigits);
  final first = rest[0];
  final tail = rest.substring(1);
  final roundUp =
      first.compareTo('5') > 0 ||
      (first == '5' && (tail.contains(RegExp('[1-9]')) || kept.isOdd));
  var integer = BigInt.parse(intPart.isEmpty ? '0' : intPart);
  if (roundUp) {
    kept += 1;
    if (kept == _centsPerUnit) {
      kept = 0;
      integer += BigInt.one;
    }
  }
  final integerText = integer.toString();
  final body = grouped ? _groupedInteger(integerText) : integerText;
  return '$body.${kept.toString().padLeft(_keptFractionDigits, '0')}';
}

String formatMoney(Decimal amount, {bool symbol = true}) {
  final negative = amount < Decimal.zero;
  final body = _roundedTwoPlaces(amount.abs(), grouped: true);
  return '${negative ? '-' : ''}${symbol ? r'S$' : ''}$body';
}

String formatSignedMoney(
  Decimal amount, {
  AmountKind? kind,
  bool symbol = true,
}) {
  final prefix = switch (kind) {
    AmountKind.income => '+',
    AmountKind.expense => '-',
    AmountKind.transfer => '',
    null =>
      amount > Decimal.zero
          ? '+'
          : amount < Decimal.zero
          ? '-'
          : '',
  };
  final body = _roundedTwoPlaces(amount.abs(), grouped: true);
  return '$prefix${symbol ? r'S$' : ''}$body';
}

String formatPlainAmount(Decimal amount) {
  final negative = amount < Decimal.zero;
  final body = _roundedTwoPlaces(amount.abs(), grouped: false);
  return '${negative ? '-' : ''}$body';
}

String formatPercent(double fraction) => _percent.format(fraction);
