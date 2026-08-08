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
  }) : id = canonicalOrNewID(id),
       subPocketIDs = Set.unmodifiable(subPocketIDs.map(canonicalID));

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
    return _copy(subPocketIDs: {...subPocketIDs, canonicalID(pocketID)});
  }

  Account removeSubPocket(String pocketID) {
    return _copy(
      subPocketIDs: {...subPocketIDs}..remove(canonicalID(pocketID)),
    );
  }

  Account settingLifecycle(LifecycleState lifecycle) {
    return _copy(lifecycle: lifecycle);
  }

  Account _copy({Set<String>? subPocketIDs, LifecycleState? lifecycle}) {
    return Account(
      id: id,
      name: name,
      type: type,
      subPocketIDs: subPocketIDs ?? this.subPocketIDs,
      incomingTransfersAsExpenses: incomingTransfersAsExpenses,
      includeInNetWorth: includeInNetWorth,
      statementDay: statementDay,
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
