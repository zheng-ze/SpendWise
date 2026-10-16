import 'package:decimal/decimal.dart';
import 'package:domain/src/entries/entry.dart';
import 'package:domain/src/entries/holder_referencing.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/plans/occurrence_id.dart';
import 'package:meta/meta.dart';

@immutable
class EntryTemplate with HolderReferencing {
  EntryTemplate({
    required this.amount,
    required this.name,
    String? categoryID,
    required String sourceID,
    String? destinationID,
    this.includeInAnalysis = true,
    String? note,
  }) : categoryID = normalizedOptionalID(categoryID),
       sourceID = normalizedID(sourceID),
       destinationID = normalizedOptionalID(destinationID),
       note = _normalizedNote(note);

  @override
  final Decimal amount;
  final String name;
  final String? categoryID;

  @override
  final String sourceID;

  @override
  final String? destinationID;

  final bool includeInAnalysis;
  final String? note;

  static String? _normalizedNote(String? raw) {
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  // MARK: - Derivers

  Entry makeEntry(String planID, DateTime date) {
    return Entry(
      id: OccurrenceID.make(planID, date),
      date: date,
      amount: amount,
      name: name,
      categoryID: categoryID,
      sourceID: sourceID,
      destinationID: destinationID,
      includeInAnalysis: includeInAnalysis,
      note: note,
    );
  }

  // MARK: - Equality

  @override
  bool operator ==(Object other) {
    return other is EntryTemplate &&
        other.amount == amount &&
        other.name == name &&
        other.categoryID == categoryID &&
        other.sourceID == sourceID &&
        other.destinationID == destinationID &&
        other.includeInAnalysis == includeInAnalysis &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(
    amount,
    name,
    categoryID,
    sourceID,
    destinationID,
    includeInAnalysis,
    note,
  );
}
