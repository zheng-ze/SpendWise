import 'package:meta/meta.dart';

@immutable
sealed class LedgerError implements Exception {
  const LedgerError();

  /// The lowerCamelCase case name, as the Swift enum spelled it.
  String get _case;
}

/// Equality is by case and id together, so two cases naming the same row stay
/// distinct. `runtimeType` carries the case, which is why no subclass needs to
/// restate either operator.
sealed class _IdentifiedError extends LedgerError {
  const _IdentifiedError(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is _IdentifiedError &&
      other.id == id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'LedgerError.$_case($id)';
}

sealed class _PlainError extends LedgerError {
  const _PlainError();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'LedgerError.$_case';
}

final class IdCollision extends _IdentifiedError {
  const IdCollision(super.id);

  @override
  String get _case => 'idCollision';
}

final class UnknownAccount extends _IdentifiedError {
  const UnknownAccount(super.id);

  @override
  String get _case => 'unknownAccount';
}

final class UnknownHolder extends _IdentifiedError {
  const UnknownHolder(super.id);

  @override
  String get _case => 'unknownHolder';
}

final class UnknownCategory extends _IdentifiedError {
  const UnknownCategory(super.id);

  @override
  String get _case => 'unknownCategory';
}

final class UnknownEntry extends _IdentifiedError {
  const UnknownEntry(super.id);

  @override
  String get _case => 'unknownEntry';
}

final class UnknownPlan extends _IdentifiedError {
  const UnknownPlan(super.id);

  @override
  String get _case => 'unknownPlan';
}

final class ExhaustedPlan extends _IdentifiedError {
  const ExhaustedPlan(super.id);

  @override
  String get _case => 'exhaustedPlan';
}

final class InactiveReference extends _IdentifiedError {
  const InactiveReference(super.id);

  @override
  String get _case => 'inactiveReference';
}

final class ZeroAmount extends _PlainError {
  const ZeroAmount();

  @override
  String get _case => 'zeroAmount';
}

final class SelfTransfer extends _PlainError {
  const SelfTransfer();

  @override
  String get _case => 'selfTransfer';
}

final class CategoryTooDeep extends _PlainError {
  const CategoryTooDeep();

  @override
  String get _case => 'categoryTooDeep';
}

final class CategoryKindMismatch extends _PlainError {
  const CategoryKindMismatch();

  @override
  String get _case => 'categoryKindMismatch';
}
