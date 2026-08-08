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
}
