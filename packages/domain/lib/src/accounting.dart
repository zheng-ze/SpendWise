import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:domain/src/account.dart';
import 'package:domain/src/analysis_item.dart';
import 'package:domain/src/category_kind.dart';
import 'package:domain/src/category_resolution.dart';
import 'package:domain/src/date_range.dart';
import 'package:domain/src/entry.dart';
import 'package:domain/src/holder_referencing.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/ledger_state.dart';
import 'package:domain/src/net_worth.dart';

/// Balances are always recomputed from the entry log, never stored.
abstract final class Accounting {
  /// [sourceIDs] is the existence set, archived rows included. Only removing a
  /// holder un-applies its entries, since archiving one would otherwise rewrite
  /// the counterparty's history.
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
    final holderID = canonicalID(of);
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

  /// Archived pockets stay linked so a restore brings them back, so
  /// [activePockets] is what keeps their balance out of the total.
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

  /// A pocket is never counted at top level, only through its parent's total.
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

      // The sign of the total picks the side, never the account type, so an
      // overdrawn debit account is a liability and a card in credit an asset.
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

  /// The window-independent pass, meant to be computed once and filtered
  /// cheaply. Output order is unspecified.
  static List<AnalysisItem> analysisItems(LedgerState ledger) {
    final sourceIDs = ledger.moneySources.keys.toSet();
    return UnmodifiableListView([
      for (final entry in ledger.entries.values)
        ...classify(entry, sourceIDs, ledger),
    ]);
  }

  /// The treat-as-expense flag is symmetric, each leg reading it off its own
  /// end, so a transfer to the holder itself emits both and nets to zero.
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
              bucketID: null,
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

        // Kind comes off the signed amount. Taking the absolute value first
        // would make every item income.
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

  static double fraction(Decimal amount, Decimal over) {
    if (over <= Decimal.zero) return 0.0;

    final ratio = (amount / over).toDouble();
    if (!ratio.isFinite) return ratio.isNegative ? -1.0 : 1.0;

    return ratio;
  }

  static String? mainBucketID(String? rawLeafID, LedgerState state) {
    final leafID = canonicalOptionalID(rawLeafID);
    if (leafID == null) return null;

    final category = state.categories[leafID];
    if (category == null) return null;

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
  /// Each null argument drops its constraint rather than matching nothing.
  List<AnalysisItem> filtered({
    CategoryKind? kind,
    Set<String?>? buckets,
    DateRange? interval,
  }) {
    // Null is a real member, the Uncategorized bucket, so it survives the map.
    final wanted = buckets?.map(canonicalOptionalID).toSet();
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
