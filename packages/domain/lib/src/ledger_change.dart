import 'package:domain/src/account.dart';
import 'package:domain/src/entry.dart';
import 'package:domain/src/money_source.dart';
import 'package:domain/src/recurring_plan.dart';
import 'package:domain/src/sub_pocket.dart';
import 'package:domain/src/transaction_category.dart';
import 'package:meta/meta.dart';

@immutable
sealed class LedgerChange {
  const LedgerChange();

  static LedgerChange upsertSource(MoneySource source) => switch (source) {
    AccountSource(:final account) => UpsertAccount(account),
    PocketSource(:final pocket) => UpsertPocket(pocket),
  };

  // Abstract, so a new case without one fails to compile.
  String get targetID;
}

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

/// Covers accounts and pockets, which share one id space.
final class DeleteMoneySource extends LedgerChange {
  const DeleteMoneySource(this.id);

  final String id;

  @override
  String get targetID => id;

  @override
  bool operator ==(Object other) =>
      other is DeleteMoneySource && other.id == id;

  @override
  int get hashCode => Object.hash(DeleteMoneySource, id);

  @override
  String toString() => 'LedgerChange.deleteMoneySource($id)';
}

final class DeleteCategory extends LedgerChange {
  const DeleteCategory(this.id);

  final String id;

  @override
  String get targetID => id;

  @override
  bool operator ==(Object other) => other is DeleteCategory && other.id == id;

  @override
  int get hashCode => Object.hash(DeleteCategory, id);

  @override
  String toString() => 'LedgerChange.deleteCategory($id)';
}

final class DeleteEntry extends LedgerChange {
  const DeleteEntry(this.id);

  final String id;

  @override
  String get targetID => id;

  @override
  bool operator ==(Object other) => other is DeleteEntry && other.id == id;

  @override
  int get hashCode => Object.hash(DeleteEntry, id);

  @override
  String toString() => 'LedgerChange.deleteEntry($id)';
}

final class DeletePlan extends LedgerChange {
  const DeletePlan(this.id);

  final String id;

  @override
  String get targetID => id;

  @override
  bool operator ==(Object other) => other is DeletePlan && other.id == id;

  @override
  int get hashCode => Object.hash(DeletePlan, id);

  @override
  String toString() => 'LedgerChange.deletePlan($id)';
}
