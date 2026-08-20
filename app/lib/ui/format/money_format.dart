import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// What an amount means, which decides how it is signed and colored when
/// displayed.
enum AmountKind { income, expense, transfer }

final NumberFormat _currency = NumberFormat.currency(symbol: r'$');

final NumberFormat _plain = NumberFormat('0.00');

final NumberFormat _percent = NumberFormat.percentPattern()
  ..maximumFractionDigits = 0;

String formatCurrency(Decimal amount) => _currency.format(amount.toDouble());

String formatSignedAmount(Decimal amount, AmountKind kind) {
  // Needs kind rather than amount's own sign, since a transfer's sign is a
  // direction and not a gain or a loss.
  final magnitude = formatCurrency(amount.abs());
  return switch (kind) {
    AmountKind.income => '+$magnitude',
    AmountKind.expense => '-$magnitude',
    AmountKind.transfer => magnitude,
  };
}

String formatPlainAmount(Decimal amount) => _plain.format(amount.toDouble());

String formatPercent(double fraction) => _percent.format(fraction);
