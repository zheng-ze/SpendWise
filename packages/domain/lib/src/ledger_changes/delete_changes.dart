part of '../ledger_change.dart';

// MARK: - Delete changes

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

final class DeleteBudget extends LedgerChange {
  const DeleteBudget(this.id);

  final String id;

  @override
  String get targetID => id;

  @override
  bool operator ==(Object other) => other is DeleteBudget && other.id == id;

  @override
  int get hashCode => Object.hash(DeleteBudget, id);

  @override
  String toString() => 'LedgerChange.deleteBudget($id)';
}
