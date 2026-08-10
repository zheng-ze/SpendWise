import 'package:collection/collection.dart';
import 'package:domain/src/ledger_change.dart';
import 'package:domain/src/plan_failure.dart';
import 'package:meta/meta.dart';

const _changeEquality = ListEquality<LedgerChange>();
const _failureEquality = ListEquality<PlanFailure>();

@immutable
class PlanResolution {
  const PlanResolution({required this.changes, required this.failures});

  final List<LedgerChange> changes;
  final List<PlanFailure> failures;

  @override
  bool operator ==(Object other) {
    return other is PlanResolution &&
        _changeEquality.equals(other.changes, changes) &&
        _failureEquality.equals(other.failures, failures);
  }

  @override
  int get hashCode => Object.hash(
    _changeEquality.hash(changes),
    _failureEquality.hash(failures),
  );
}
