import 'package:domain/src/ids.dart';
import 'package:domain/src/plan_scheduling.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const _namespace = '8b9e0c42-5f3a-4d71-9c2e-1a6b7f0d3e85';

abstract final class OccurrenceID {
  /// Deterministic so that two devices resolving the same occurrence converge
  /// on one entry instead of each minting a random id and duplicating it.
  static String make(String planID, DateTime occurrenceDay) {
    final day = startOfDayUtc(occurrenceDay);
    // Reference date is 2001-01-01, not the Unix epoch.
    final seconds = day.difference(DateTime.utc(2001)).inSeconds;
    final name = '${canonicalID(planID)}|$seconds';
    return canonicalID(_uuid.v5(_namespace, name));
  }
}
