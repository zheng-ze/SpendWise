import 'package:domain/domain.dart';

bool canSaveSourceEditForm({required String name, required Decimal? balance}) {
  if (name.trim().isEmpty) return false;
  return balance != null;
}

/// Builds the entry that reconciles the current balance to the entered one,
/// or null if the two already match.
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
