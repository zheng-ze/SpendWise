import 'package:domain/src/ledger_change.dart';
import 'package:domain/src/plan_failure.dart';
import 'package:meta/meta.dart';

@immutable
class PlanResolution {
  const PlanResolution({required this.changes, required this.failures});

  final List<LedgerChange> changes;
  final List<PlanFailure> failures;
}
