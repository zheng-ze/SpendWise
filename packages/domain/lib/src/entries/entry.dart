import 'package:decimal/decimal.dart';
import 'package:domain/src/entries/holder_referencing.dart';
import 'package:domain/src/entries/system_entry_kind.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:domain/src/time/calendar_day.dart';
import 'package:meta/meta.dart';

// MARK: - Model

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
    String? note,
  }) : id = normalizedOrNewID(id),
       date = startOfDayUtc(date ?? DateTime.now()),
       categoryID = normalizedOptionalID(categoryID),
       sourceID = normalizedID(sourceID),
       destinationID = normalizedOptionalID(destinationID),
       note = _normalizedNote(note);

  final String id;
  final DateTime date;

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
  final String? note;

  static String? _normalizedNote(String? raw) {
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  // MARK: - Derivers

  Entry settingLifecycle(LifecycleState lifecycle) => Entry(
    id: id,
    date: date,
    amount: amount,
    name: name,
    categoryID: categoryID,
    sourceID: sourceID,
    destinationID: destinationID,
    includeInAnalysis: includeInAnalysis,
    lifecycle: lifecycle,
    systemKind: systemKind,
    note: note,
  );

  // MARK: - Equality

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
        other.systemKind == systemKind &&
        other.note == note;
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
    note,
  );
}
