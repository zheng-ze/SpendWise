import 'package:decimal/decimal.dart';
import 'package:domain/src/calendar_day.dart';
import 'package:domain/src/holder_referencing.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:meta/meta.dart';

/// Marks an entry the app generates itself rather than one a user typed in,
/// so the UI and the ledger can tell the two apart and protect the
/// generated one from edits that would corrupt what it stands for.
enum SystemEntryKind {
  openingBalance(0),
  balanceAdjustment(1);

  const SystemEntryKind(this.code);

  final int code;

  static SystemEntryKind? fromCode(int? code) => switch (code) {
    0 => openingBalance,
    1 => balanceAdjustment,
    _ => null,
  };
}

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
    this.systemKind,
  }) : id = normalizedOrNewID(id),
       date = startOfDayUtc(date ?? DateTime.now()),
       categoryID = normalizedOptionalID(categoryID),
       sourceID = normalizedID(sourceID),
       destinationID = normalizedOptionalID(destinationID);

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
  final SystemEntryKind? systemKind;

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
        other.lifecycle == lifecycle &&
        other.systemKind == systemKind;
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
    systemKind,
  );
}
