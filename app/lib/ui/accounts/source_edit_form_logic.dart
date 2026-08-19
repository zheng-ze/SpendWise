import 'package:domain/domain.dart';

bool canSaveSourceEditForm({required String name, required Decimal? balance}) {
  if (name.trim().isEmpty) return false;
  return balance != null;
}

/// Empty text counts as zero, matching the form's own convention for the
/// balance field rather than treating a blank entry as unparsed.
Decimal parseEnteredBalance(String text) {
  if (text.trim().isEmpty) return Decimal.zero;
  return Decimal.tryParse(text) ?? Decimal.zero;
}

/// Null when the entered balance matches the current one, so the caller can
/// tell "no adjustment" apart from "adjustment of zero" without posting a
/// zero-value entry either way.
Entry? balanceAdjustmentEntry({
  required Decimal enteredBalance,
  required Decimal currentBalance,
  required String holderID,
  DateTime? date,
}) {
  final delta = enteredBalance - currentBalance;
  if (delta == Decimal.zero) return null;

  return Entry(
    date: date,
    amount: delta,
    name: 'Balance adjustment',
    sourceID: holderID,
    includeInAnalysis: false,
    systemKind: SystemEntryKind.balanceAdjustment,
  );
}
