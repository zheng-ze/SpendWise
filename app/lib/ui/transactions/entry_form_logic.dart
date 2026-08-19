import 'package:domain/domain.dart';

enum EntryFormKind { expense, income, transfer }

bool canSaveEntryForm({
  required Decimal? amount,
  required String name,
  required String? sourceId,
  required EntryFormKind kind,
  required String? destinationId,
}) {
  if (amount == null || amount == Decimal.zero) return false;
  if (name.trim().isEmpty) return false;
  if (sourceId == null) return false;

  if (kind == EntryFormKind.transfer) {
    if (destinationId == null) return false;
    if (destinationId == sourceId) return false;
  }

  return true;
}

/// Applies the stored sign for the kind: income positive, expense negative,
/// transfer positive with no category. `magnitude` must already be positive.
Entry signedEntryForSave({
  required EntryFormKind kind,
  required Decimal magnitude,
  String? id,
  DateTime? date,
  required String name,
  String? categoryId,
  required String sourceId,
  String? destinationId,
  required bool includeInAnalysis,
}) {
  final amount = kind == EntryFormKind.expense ? -magnitude : magnitude;

  return Entry(
    id: id,
    date: date,
    amount: amount,
    name: name,
    categoryID: kind == EntryFormKind.transfer ? null : categoryId,
    sourceID: sourceId,
    destinationID: kind == EntryFormKind.transfer ? destinationId : null,
    includeInAnalysis: includeInAnalysis,
  );
}

/// One calendar day behind the anchor, so a half-open scan starting after
/// this date still includes the anchor day itself.
RecurringPlan buildRecurringPlanForNewEntry({
  required EntryTemplate template,
  required RecurrenceFrequency frequency,
  required DateTime anchor,
  DateTime? endDate,
}) {
  return RecurringPlan(
    template: template,
    frequency: frequency,
    anchor: anchor,
    endDate: endDate,
    lastResolvedDate: anchor.subtract(const Duration(days: 1)),
  );
}
