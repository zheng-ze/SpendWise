import 'package:domain/src/ledger_error.dart';
import 'package:meta/meta.dart';

@immutable
class PlanFailure {
  const PlanFailure({
    required this.planID,
    required this.occurrence,
    required this.error,
  });

  final String planID;
  final DateTime occurrence;
  final LedgerError error;

  @override
  bool operator ==(Object other) =>
      other is PlanFailure &&
      other.planID == planID &&
      other.occurrence == occurrence &&
      other.error == error;

  @override
  int get hashCode => Object.hash(planID, occurrence, error);

  @override
  String toString() => 'PlanFailure($planID, $occurrence, $error)';
}
