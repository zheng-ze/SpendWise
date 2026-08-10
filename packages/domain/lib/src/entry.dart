import 'package:decimal/decimal.dart';
import 'package:domain/src/calendar_day.dart';
import 'package:domain/src/holder_referencing.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:meta/meta.dart';

@immutable
class Entry with HolderReferencing {
  Entry({
    String? id,
    DateTime? date,
    required this.amount,
    required this.name,
    String? categoryID,
    required String sourceID,
    String? destinationID,
    this.includeInAnalysis = true,
    this.lifecycle = LifecycleState.active,
  }) : id = canonicalOrNewID(id),
       date = startOfDayUtc(date ?? DateTime.now()),
       categoryID = canonicalOptionalID(categoryID),
       sourceID = canonicalID(sourceID),
       destinationID = canonicalOptionalID(destinationID);

  final String id;
  final DateTime date;

  /// Signed. Income positive, expense negative. Stored transfers are positive.
  @override
  final Decimal amount;

  final String name;
  final String? categoryID;

  @override
  final String sourceID;

  @override
  final String? destinationID;

  final bool includeInAnalysis;
  final LifecycleState lifecycle;

  @override
  bool operator ==(Object other) {
    return other is Entry &&
        other.id == id &&
        other.date == date &&
        other.amount == amount &&
        other.name == name &&
        other.categoryID == categoryID &&
        other.sourceID == sourceID &&
        other.destinationID == destinationID &&
        other.includeInAnalysis == includeInAnalysis &&
        other.lifecycle == lifecycle;
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    amount,
    name,
    categoryID,
    sourceID,
    destinationID,
    includeInAnalysis,
    lifecycle,
  );
}
