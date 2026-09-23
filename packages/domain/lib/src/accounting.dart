import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:domain/src/accounts/account.dart';
import 'package:domain/src/accounts/account_type.dart';
import 'package:domain/src/accounts/money_source.dart';
import 'package:domain/src/analysis/analysis_item.dart';
import 'package:domain/src/analysis/net_worth.dart';
import 'package:domain/src/analysis/synthetic_buckets.dart';
import 'package:domain/src/entries/category_kind.dart';
import 'package:domain/src/entries/category_resolution.dart';
import 'package:domain/src/entries/entry.dart';
import 'package:domain/src/entries/holder_referencing.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/ledger_state/ledger_state.dart';
import 'package:domain/src/time/date_range.dart';

abstract final class Accounting {
  static bool applies(Entry entry, Set<String> sourceIDs) {
    if (!sourceIDs.contains(entry.sourceID)) return false;

    final destination = entry.destinationID;
    if (destination == null) return true;

    return sourceIDs.contains(destination);
  }

  static Decimal balance({
    required String of,
    required List<Entry> entries,
    required Set<String> sourceIDs,
  }) {
    final holderID = normalizedID(of);
    var total = Decimal.zero;
    for (final entry in entries) {
      if (!applies(entry, sourceIDs)) continue;

      if (entry.isTransfer) {
        if (entry.destinationID == holderID) total += entry.amount;
        if (entry.sourceID == holderID) total -= entry.amount;
      } else if (entry.sourceID == holderID) {
        total += entry.amount;
      }
    }
    return total;
  }

  static Decimal accountTotal(
    Account account, {
    required List<Entry> entries,
    required Set<String> sourceIDs,
    required Set<String> activePockets,
  }) {
    var total = balance(of: account.id, entries: entries, sourceIDs: sourceIDs);
    for (final pocketID in account.subPocketIDs) {
      if (!activePockets.contains(pocketID)) continue;

      total += balance(of: pocketID, entries: entries, sourceIDs: sourceIDs);
    }
    return total;
  }

  static NetWorth netWorth(LedgerState ledger) {
    final sourceIDs = ledger.moneySources.keys.toSet();
    final activePockets = ledger.activeSources;
    final entries = ledger.entries.values.toList();

    var asset = Decimal.zero;
    var liability = Decimal.zero;

    for (final source in ledger.moneySources.values) {
      final account = source.asAccount;
      if (account == null ||
          !account.lifecycle.isActive ||
          !account.includeInNetWorth) {
        continue;
      }

      final total = accountTotal(
        account,
        entries: entries,
        sourceIDs: sourceIDs,
        activePockets: activePockets,
      );
      if (total < Decimal.zero) {
        liability -= total;
      } else {
        asset += total;
      }
    }

    return NetWorth(asset, liability);
  }

  static List<AnalysisItem> analysisItems(LedgerState ledger) {
    final sourceIDs = ledger.moneySources.keys.toSet();
    return UnmodifiableListView([
      for (final entry in ledger.entries.values)
        ...classify(entry, sourceIDs, ledger),
    ]);
  }

  static List<AnalysisItem> classify(
    Entry entry,
    Set<String> sourceIDs,
    LedgerState ledger,
  ) {
    if (!applies(entry, sourceIDs) || !entry.includeInAnalysis) {
      return const [];
    }

    switch (entry.kind) {
      case EntryKind.transfer:
        final destination = entry.destinationID;
        if (destination == null) return const [];

        final sources = ledger.moneySources;
        return [
          if (sources[destination]?.incomingTransfersAsExpenses == true)
            AnalysisItem(
              bucketID: syntheticTransferExpenseBucketID(
                _destinationAccountType(sources[destination]!, ledger),
              ),
              amount: entry.amount,
              date: entry.date,
              kind: CategoryKind.expense,
            ),
          if (sources[entry.sourceID]?.incomingTransfersAsExpenses == true)
            AnalysisItem(
              bucketID: null,
              amount: entry.amount,
              date: entry.date,
              kind: CategoryKind.income,
            ),
        ];

      case EntryKind.income:
      case EntryKind.expense:
        final String? bucketID;
        switch (resolveCategory(entry, ledger)) {
          case Excluded():
            return const [];
          case Uncategorized():
            bucketID = null;
          case InCategory(:final id):
            bucketID = id;
        }

        final kind = entry.expectedCategoryKind;
        if (kind == null) return const [];

        return [
          AnalysisItem(
            bucketID: bucketID,
            amount: entry.amount.abs(),
            date: entry.date,
            kind: kind,
          ),
        ];
    }
  }

  static ({Decimal income, Decimal expense}) totals(
    Entry entry,
    LedgerState ledger, {
    required Set<String> sourceIDs,
  }) {
    if (!applies(entry, sourceIDs) || !entry.includeInAnalysis) {
      return (income: Decimal.zero, expense: Decimal.zero);
    }

    switch (entry.kind) {
      case EntryKind.transfer:
        final destination = entry.destinationID;
        if (destination == null) {
          return (income: Decimal.zero, expense: Decimal.zero);
        }

        final sources = ledger.moneySources;
        var income = Decimal.zero;
        var expense = Decimal.zero;
        if (sources[destination]?.incomingTransfersAsExpenses == true) {
          expense = entry.amount;
        }
        if (sources[entry.sourceID]?.incomingTransfersAsExpenses == true) {
          income = entry.amount;
        }
        return (income: income, expense: expense);

      case EntryKind.income:
        return (income: entry.amount, expense: Decimal.zero);

      case EntryKind.expense:
        return (income: Decimal.zero, expense: -entry.amount);
    }
  }

  static AccountType _destinationAccountType(
    MoneySource destination,
    LedgerState ledger,
  ) {
    final account =
        destination.asAccount ?? ledger.owningAccount(destination.id);
    return account!.type;
  }

  static CategoryResolution resolveCategory(Entry entry, LedgerState ledger) {
    final categoryID = entry.categoryID;
    if (categoryID == null) return const Uncategorized();

    final category = ledger.categories[categoryID];
    if (category == null) return const Uncategorized();
    if (!category.includeInAnalysis) return const Excluded();

    final parentID = category.parentID;
    if (parentID != null &&
        ledger.categories[parentID]?.includeInAnalysis == false) {
      return const Excluded();
    }

    return InCategory(categoryID);
  }

  static bool includedInAnalysis(Entry entry, LedgerState ledger) {
    if (!entry.includeInAnalysis) return false;
    return resolveCategory(entry, ledger) is! Excluded;
  }

  static double fraction(Decimal amount, Decimal over) {
    if (over <= Decimal.zero) return 0.0;

    final ratio = (amount / over).toDouble();
    if (!ratio.isFinite) return ratio.isNegative ? -1.0 : 1.0;

    return ratio;
  }

  static String? mainBucketID(String? rawLeafID, LedgerState state) {
    final leafID = normalizedOptionalID(rawLeafID);
    if (leafID == null) return null;

    final category = state.categories[leafID];
    if (category == null) return leafID;

    return category.parentID ?? category.id;
  }

  static Map<String?, Decimal> rollUp(
    List<AnalysisItem> items,
    LedgerState state,
  ) {
    final sums = <String?, Decimal>{};
    for (final item in items) {
      final bucketID = mainBucketID(item.bucketID, state);
      sums[bucketID] = (sums[bucketID] ?? Decimal.zero) + item.amount;
    }
    return UnmodifiableMapView(sums);
  }
}

extension AnalysisItemList on List<AnalysisItem> {
  List<AnalysisItem> filtered({
    CategoryKind? kind,
    Set<String?>? buckets,
    DateRange? interval,
  }) {
    final wanted = buckets?.map(normalizedOptionalID).toSet();
    return UnmodifiableListView(
      where((item) {
        if (kind != null && item.kind != kind) return false;
        if (wanted != null && !wanted.contains(item.bucketID)) return false;
        if (interval != null && !interval.contains(item.date)) return false;

        return true;
      }).toList(),
    );
  }

  Decimal total({
    CategoryKind? kind,
    Set<String?>? buckets,
    DateRange? interval,
  }) {
    return filtered(
      kind: kind,
      buckets: buckets,
      interval: interval,
    ).fold(Decimal.zero, (sum, item) => sum + item.amount);
  }
}
