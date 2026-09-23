import 'package:domain/domain.dart';

Decimal? parseAmountInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return Decimal.zero;
  return Decimal.tryParse(trimmed);
}
