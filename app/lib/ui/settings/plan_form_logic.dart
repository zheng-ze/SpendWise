import 'package:domain/domain.dart';

bool canSavePlanForm({required String name, required Decimal amount}) {
  if (name.trim().isEmpty) return false;
  if (amount == Decimal.zero) return false;
  return true;
}

/// Carries the template's original sign onto the freshly typed magnitude.
Decimal applyOriginalSign({
  required Decimal magnitude,
  required Decimal originalAmount,
}) {
  // Keeps an expense plan from silently becoming an income plan through this form.
  return originalAmount < Decimal.zero ? -magnitude : magnitude;
}

/// Returns [picked], or [current] if the picker returned null.
RecurrenceFrequency applyPickerResult(
  RecurrenceFrequency current,
  RecurrenceFrequency? picked,
) => picked ?? current;
