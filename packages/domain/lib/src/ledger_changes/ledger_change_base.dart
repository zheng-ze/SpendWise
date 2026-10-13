part of '../ledger_change.dart';

// MARK: - Base

@immutable
sealed class LedgerChange {
  const LedgerChange();

  static LedgerChange upsertSource(MoneySource source) => switch (source) {
    AccountSource(:final account) => UpsertAccount(account),
    PocketSource(:final pocket) => UpsertPocket(pocket),
  };

  String get targetID;
}
