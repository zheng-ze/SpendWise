import 'package:decimal/decimal.dart';
import 'package:domain/src/account.dart';
import 'package:domain/src/entry.dart';
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
    var total = Decimal.zero;
    for (final entry in entries) {
      if (!applies(entry, sourceIDs)) continue;

      if (entry.isTransfer) {
        if (entry.destinationID == of) total += entry.amount;
        if (entry.sourceID == of) total -= entry.amount;
      } else if (entry.sourceID == of) {
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
}
