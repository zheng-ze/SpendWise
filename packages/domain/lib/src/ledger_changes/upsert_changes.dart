part of '../ledger_change.dart';

// MARK: - Upsert changes

final class UpsertAccount extends LedgerChange {
  const UpsertAccount(this.account);

  final Account account;

  @override
  String get targetID => account.id;

  @override
  bool operator ==(Object other) =>
      other is UpsertAccount && other.account == account;

  @override
  int get hashCode => Object.hash(UpsertAccount, account);

  @override
  String toString() => 'LedgerChange.upsertAccount(${account.id})';
}

final class UpsertPocket extends LedgerChange {
  const UpsertPocket(this.pocket);

  final SubPocket pocket;

  @override
  String get targetID => pocket.id;

  @override
  bool operator ==(Object other) =>
      other is UpsertPocket && other.pocket == pocket;

  @override
  int get hashCode => Object.hash(UpsertPocket, pocket);

  @override
  String toString() => 'LedgerChange.upsertPocket(${pocket.id})';
}

final class UpsertCategory extends LedgerChange {
  const UpsertCategory(this.category);

  final TransactionCategory category;

  @override
  String get targetID => category.id;

  @override
  bool operator ==(Object other) =>
      other is UpsertCategory && other.category == category;

  @override
  int get hashCode => Object.hash(UpsertCategory, category);

  @override
  String toString() => 'LedgerChange.upsertCategory(${category.id})';
}

final class UpsertEntry extends LedgerChange {
  const UpsertEntry(this.entry);

  final Entry entry;

  @override
  String get targetID => entry.id;

  @override
  bool operator ==(Object other) =>
      other is UpsertEntry && other.entry == entry;

  @override
  int get hashCode => Object.hash(UpsertEntry, entry);

  @override
  String toString() => 'LedgerChange.upsertEntry(${entry.id})';
}

final class UpsertPlan extends LedgerChange {
  const UpsertPlan(this.plan);

  final RecurringPlan plan;

  @override
  String get targetID => plan.id;

  @override
  bool operator ==(Object other) => other is UpsertPlan && other.plan == plan;

  @override
  int get hashCode => Object.hash(UpsertPlan, plan);

  @override
  String toString() => 'LedgerChange.upsertPlan(${plan.id})';
}

final class UpsertBudget extends LedgerChange {
  const UpsertBudget(this.budget);

  final Budget budget;

  @override
  String get targetID => budget.id;

  @override
  bool operator ==(Object other) =>
      other is UpsertBudget && other.budget == budget;

  @override
  int get hashCode => Object.hash(UpsertBudget, budget);

  @override
  String toString() => 'LedgerChange.upsertBudget(${budget.id})';
}
