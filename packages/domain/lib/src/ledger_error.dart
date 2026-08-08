import 'package:meta/meta.dart';

@immutable
sealed class LedgerError implements Exception {
  const LedgerError();
}

final class IdCollision extends LedgerError {
  const IdCollision(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is IdCollision && other.id == id;

  @override
  int get hashCode => Object.hash(IdCollision, id);

  @override
  String toString() => 'LedgerError.idCollision($id)';
}

final class UnknownAccount extends LedgerError {
  const UnknownAccount(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is UnknownAccount && other.id == id;

  @override
  int get hashCode => Object.hash(UnknownAccount, id);

  @override
  String toString() => 'LedgerError.unknownAccount($id)';
}

final class UnknownHolder extends LedgerError {
  const UnknownHolder(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is UnknownHolder && other.id == id;

  @override
  int get hashCode => Object.hash(UnknownHolder, id);

  @override
  String toString() => 'LedgerError.unknownHolder($id)';
}

final class UnknownCategory extends LedgerError {
  const UnknownCategory(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is UnknownCategory && other.id == id;

  @override
  int get hashCode => Object.hash(UnknownCategory, id);

  @override
  String toString() => 'LedgerError.unknownCategory($id)';
}

final class UnknownEntry extends LedgerError {
  const UnknownEntry(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is UnknownEntry && other.id == id;

  @override
  int get hashCode => Object.hash(UnknownEntry, id);

  @override
  String toString() => 'LedgerError.unknownEntry($id)';
}

final class ZeroAmount extends LedgerError {
  const ZeroAmount();

  @override
  bool operator ==(Object other) => other is ZeroAmount;

  @override
  int get hashCode => Object.hash(ZeroAmount, 0);

  @override
  String toString() => 'LedgerError.zeroAmount';
}

final class SelfTransfer extends LedgerError {
  const SelfTransfer();

  @override
  bool operator ==(Object other) => other is SelfTransfer;

  @override
  int get hashCode => Object.hash(SelfTransfer, 0);

  @override
  String toString() => 'LedgerError.selfTransfer';
}

final class CategoryTooDeep extends LedgerError {
  const CategoryTooDeep();

  @override
  bool operator ==(Object other) => other is CategoryTooDeep;

  @override
  int get hashCode => Object.hash(CategoryTooDeep, 0);

  @override
  String toString() => 'LedgerError.categoryTooDeep';
}

final class CategoryKindMismatch extends LedgerError {
  const CategoryKindMismatch();

  @override
  bool operator ==(Object other) => other is CategoryKindMismatch;

  @override
  int get hashCode => Object.hash(CategoryKindMismatch, 0);

  @override
  String toString() => 'LedgerError.categoryKindMismatch';
}

final class InactiveReference extends LedgerError {
  const InactiveReference(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is InactiveReference && other.id == id;

  @override
  int get hashCode => Object.hash(InactiveReference, id);

  @override
  String toString() => 'LedgerError.inactiveReference($id)';
}
