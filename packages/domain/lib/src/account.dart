import 'package:collection/collection.dart';
import 'package:domain/src/account_type.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:meta/meta.dart';

const _idEquality = SetEquality<String>();

@immutable
class Account {
  Account({
    String? id,
    required this.name,
    required this.type,
    Set<String> subPocketIDs = const {},
    this.incomingTransfersAsExpenses = false,
    this.includeInNetWorth = true,
    this.statementDay,
    this.lifecycle = LifecycleState.active,
  }) : id = normalizedOrNewID(id),
       subPocketIDs = Set.unmodifiable(subPocketIDs.map(normalizedID));

  final String id;
  final String name;
  final AccountType type;
  final Set<String> subPocketIDs;
  final bool incomingTransfersAsExpenses;
  final bool includeInNetWorth;

  /// Day of month the card statement cuts. Meaningful only for card accounts.
  final int? statementDay;

  final LifecycleState lifecycle;

  Account addSubPocket(String pocketID) {
    return _copy(subPocketIDs: {...subPocketIDs, normalizedID(pocketID)});
  }

  Account removeSubPocket(String pocketID) {
    return _copy(
      subPocketIDs: {...subPocketIDs}..remove(normalizedID(pocketID)),
    );
  }

  Account withSubPockets(Set<String> pocketIDs) {
    return _copy(subPocketIDs: pocketIDs);
  }

  Account settingLifecycle(LifecycleState lifecycle) {
    return _copy(lifecycle: lifecycle);
  }

  /// Out-of-range values are clamped into 1-28 rather than rejected.
  Account withNormalizedStatementDay() {
    // Clamped rather than rejected: a value reaching here came from a drift
    // row or an import, and dropping the row would lose more.
    final normalized = type == AccountType.card && statementDay != null
        ? statementDay!.clamp(1, 28)
        : null;
    return normalized == statementDay
        ? this
        : _copy(statementDay: () => normalized);
  }

  Account withEligibleTransferFlag() {
    final allowed =
        type.allowsTransfersAsExpense && incomingTransfersAsExpenses;
    return allowed == incomingTransfersAsExpenses
        ? this
        : _copy(incomingTransfersAsExpenses: allowed);
  }

  Account _copy({
    Set<String>? subPocketIDs,
    LifecycleState? lifecycle,
    int? Function()? statementDay,
    bool? incomingTransfersAsExpenses,
  }) {
    return Account(
      id: id,
      name: name,
      type: type,
      subPocketIDs: subPocketIDs ?? this.subPocketIDs,
      incomingTransfersAsExpenses:
          incomingTransfersAsExpenses ?? this.incomingTransfersAsExpenses,
      includeInNetWorth: includeInNetWorth,
      statementDay: statementDay == null ? this.statementDay : statementDay(),
      lifecycle: lifecycle ?? this.lifecycle,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Account &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        _idEquality.equals(other.subPocketIDs, subPocketIDs) &&
        other.incomingTransfersAsExpenses == incomingTransfersAsExpenses &&
        other.includeInNetWorth == includeInNetWorth &&
        other.statementDay == statementDay &&
        other.lifecycle == lifecycle;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    _idEquality.hash(subPocketIDs),
    incomingTransfersAsExpenses,
    includeInNetWorth,
    statementDay,
    lifecycle,
  );
}
