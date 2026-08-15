import 'package:domain/domain.dart';

bool canSavePlanForm({required String name, required Decimal amount}) {
  if (name.trim().isEmpty) return false;
  if (amount == Decimal.zero) return false;
  return true;
}

/// Carries the template's original sign onto the freshly typed magnitude, so
/// an expense plan cannot silently become an income plan through this form.
Decimal applyOriginalSign({
  required Decimal magnitude,
  required Decimal originalAmount,
}) {
  return originalAmount < Decimal.zero ? -magnitude : magnitude;
}

/// The picker returns null both when the sheet is dismissed and when the
/// user explicitly chooses "one time" (null is one-time in this model), so
/// either way a null result keeps the plan's current frequency.
RecurrenceFrequency applyPickerResult(
  RecurrenceFrequency current,
  RecurrenceFrequency? picked,
) => picked ?? current;
