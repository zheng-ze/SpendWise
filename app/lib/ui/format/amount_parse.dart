import 'package:domain/domain.dart';

/// Parses a form field's raw amount text, treating blank input as zero and
/// unparseable text as null rather than silently defaulting it to zero.
Decimal? parseAmountInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return Decimal.zero;
  return Decimal.tryParse(trimmed);
}
