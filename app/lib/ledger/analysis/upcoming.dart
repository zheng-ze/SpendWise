import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

import 'package:spendwise/ledger/analysis/entry_record.dart';

@immutable
class PlanOccurrence {
  const PlanOccurrence({
    required this.planID,
    required this.occurrenceID,
    required this.date,
    required this.projected,
  });

  final String planID;
  final String occurrenceID;
  final DateTime date;
  final EntryRecord projected;

  @override
  bool operator ==(Object other) {
    return other is PlanOccurrence &&
        other.planID == planID &&
        other.occurrenceID == occurrenceID &&
        other.date == date &&
        other.projected == projected;
  }

  @override
  int get hashCode => Object.hash(planID, occurrenceID, date, projected);
}

sealed class UpcomingItem {
  const UpcomingItem();

  DateTime get date;
}

final class UpcomingEntry extends UpcomingItem {
  const UpcomingEntry(this.record);

  final EntryRecord record;

  @override
  DateTime get date => record.entry.date;

  @override
  bool operator ==(Object other) {
    return other is UpcomingEntry && other.record == record;
  }

  @override
  int get hashCode => record.hashCode;
}

final class UpcomingPlan extends UpcomingItem {
  const UpcomingPlan(this.occurrence);

  final PlanOccurrence occurrence;

  @override
  DateTime get date => occurrence.date;

  @override
  bool operator ==(Object other) {
    return other is UpcomingPlan && other.occurrence == occurrence;
  }

  @override
  int get hashCode => occurrence.hashCode;
}

final class UpcomingStatement extends UpcomingItem {
  UpcomingStatement({
    required String accountID,
    required this.accountName,
    required this.date,
    required this.cycleAmount,
  }) : accountID = normalizedID(accountID);

  final String accountID;
  final String? accountName;
  @override
  final DateTime date;
  final Decimal cycleAmount;

  @override
  bool operator ==(Object other) {
    return other is UpcomingStatement &&
        other.accountID == accountID &&
        other.accountName == accountName &&
        other.date == date &&
        other.cycleAmount == cycleAmount;
  }

  @override
  int get hashCode => Object.hash(accountID, accountName, date, cycleAmount);
}

List<UpcomingItem> upcomingItems({
  required LedgerState ledger,
  required DateTime today,
  required DateRange window,
  Set<String>? sourceIDs,
}) {
  final day = startOfDayUtc(today);
  final range = normalizedWindow(window);
  final scope = normalizedScope(sourceIDs);
  final items = <UpcomingItem>[
    for (final entry in ledger.entries.values)
      if (entry.lifecycle.isActive &&
          inScope(entry, scope) &&
          range.contains(entry.date) &&
          entry.date.isAfter(day))
        UpcomingEntry(entryRecord(ledger, entry)),
    for (final occurrence in upcomingPlanOccurrences(
      ledger: ledger,
      today: day,
      window: range,
      sourceIDs: scope,
    ))
      UpcomingPlan(occurrence),
    for (final statement in _upcomingStatements(
      ledger: ledger,
      today: day,
      window: range,
      scope: scope,
    ))
      statement,
  ];
  items.sort(_byDateThenKindThenID);
  return List.unmodifiable(items);
}

List<PlanOccurrence> upcomingPlanOccurrences({
  required LedgerState ledger,
  required DateTime today,
  required DateRange window,
  Set<String>? sourceIDs,
}) {
  final day = startOfDayUtc(today);
  final range = normalizedWindow(window);
  final scope = normalizedScope(sourceIDs);
  final floor = (range.start.isAfter(day) ? range.start : day).subtract(
    const Duration(days: 1),
  );
  final upTo = range.end.subtract(const Duration(days: 1));
  final occurrences = <PlanOccurrence>[];
  for (final plan in ledger.plans.values) {
    if (!inScope(plan.template, scope)) continue;
    var after = plan.lastResolvedDate;
    if (floor.isAfter(after)) after = floor;
    for (final date in plan.occurrences(after: after, upTo: upTo)) {
      final occurrenceID = OccurrenceID.make(plan.id, date);
      if (ledger.entries.containsKey(occurrenceID) ||
          ledger.binnedEntries.containsKey(occurrenceID)) {
        continue;
      }
      final resolved = ledger.resolvedEntryOrNull(
        plan.template.makeEntry(plan.id, date),
      );
      if (resolved == null) continue;
      occurrences.add(
        PlanOccurrence(
          planID: plan.id,
          occurrenceID: occurrenceID,
          date: date,
          projected: entryRecord(ledger, resolved),
        ),
      );
    }
  }
  return occurrences;
}

List<UpcomingStatement> _upcomingStatements({
  required LedgerState ledger,
  required DateTime today,
  required DateRange window,
  required Set<String>? scope,
}) {
  final statements = <UpcomingStatement>[];
  for (final source in ledger.moneySources.values) {
    final account = source.asAccount;
    if (account == null) continue;
    if (scope != null && !scope.contains(account.id)) continue;
    var statement = cardStatement(
      ledger: ledger,
      accountID: account.id,
      today: today,
    );
    if (statement == null) continue;
    if (statement.currentCycle.start == today) {
      statement = cardStatement(
        ledger: ledger,
        accountID: account.id,
        today: today.subtract(const Duration(days: 1)),
      );
      if (statement == null) continue;
    }
    if (!window.contains(statement.nextCut)) continue;
    statements.add(
      UpcomingStatement(
        accountID: statement.accountID,
        accountName: ledger.sourceName(statement.accountID),
        date: statement.nextCut,
        cycleAmount: statement.cycleAmount,
      ),
    );
  }
  return statements;
}

int _byDateThenKindThenID(UpcomingItem a, UpcomingItem b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final byKind = _kindRank(a).compareTo(_kindRank(b));
  if (byKind != 0) return byKind;
  return _tieID(a).compareTo(_tieID(b));
}

int _kindRank(UpcomingItem item) => switch (item) {
  UpcomingStatement() => 0,
  UpcomingPlan() => 1,
  UpcomingEntry() => 2,
};

String _tieID(UpcomingItem item) => switch (item) {
  UpcomingStatement(:final accountID) => accountID,
  UpcomingPlan(:final occurrence) => occurrence.planID,
  UpcomingEntry(:final record) => record.entry.id,
};
