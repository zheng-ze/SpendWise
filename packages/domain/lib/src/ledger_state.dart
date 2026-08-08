import 'package:domain/src/account.dart';
import 'package:domain/src/account_type.dart';
import 'package:domain/src/entry.dart';
import 'package:domain/src/ledger_change.dart';
import 'package:domain/src/ledger_error.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:domain/src/money_source.dart';
import 'package:domain/src/sub_pocket.dart';
import 'package:domain/src/transaction_category.dart';

part 'ledger_state_queries.dart';

class LedgerState {
  LedgerState({
    Map<String, MoneySource>? moneySources,
    Map<String, Entry>? entries,
    Map<String, TransactionCategory>? categories,
  }) : moneySources = moneySources ?? {},
       entries = entries ?? {},
       categories = categories ?? {};

  /// Accounts and pockets share this table and its id space.
  final Map<String, MoneySource> moneySources;

  final Map<String, Entry> entries;
  final Map<String, TransactionCategory> categories;

  List<LedgerChange> addAccount(Account account) {
    if (moneySources.containsKey(account.id)) {
      throw IdCollision(account.id);
    }
    final stored = Account(
      id: account.id,
      name: account.name,
      type: account.type,
      incomingTransfersAsExpenses: account.incomingTransfersAsExpenses,
      includeInNetWorth: account.includeInNetWorth,
      statementDay: account.statementDay,
      lifecycle: account.lifecycle,
    );
    moneySources[stored.id] = AccountSource(stored);
    return [UpsertAccount(stored)];
  }

  List<LedgerChange> updateAccount(Account account) {
    final existing = moneySources[account.id]?.asAccount;
    if (existing == null) throw UnknownAccount(account.id);

    final stored = Account(
      id: account.id,
      name: account.name,
      type: account.type,
      subPocketIDs: existing.subPocketIDs,
      incomingTransfersAsExpenses: account.incomingTransfersAsExpenses,
      includeInNetWorth: account.includeInNetWorth,
      statementDay: account.type == AccountType.card
          ? account.statementDay
          : null,
      lifecycle: account.lifecycle,
    );
    moneySources[stored.id] = AccountSource(stored);
    return [UpsertAccount(stored)];
  }

  List<LedgerChange> addPocket(SubPocket pocket, String accountID) {
    final parent = moneySources[accountID]?.asAccount;
    if (parent == null) throw UnknownAccount(accountID);
    if (moneySources.containsKey(pocket.id)) throw IdCollision(pocket.id);

    final linked = parent.addSubPocket(pocket.id);
    moneySources[pocket.id] = PocketSource(pocket);
    moneySources[linked.id] = AccountSource(linked);
    return [UpsertPocket(pocket), UpsertAccount(linked)];
  }

  List<LedgerChange> updatePocket(SubPocket pocket) {
    if (moneySources[pocket.id]?.asPocket == null) {
      throw UnknownHolder(pocket.id);
    }
    moneySources[pocket.id] = PocketSource(pocket);
    return [UpsertPocket(pocket)];
  }
}
