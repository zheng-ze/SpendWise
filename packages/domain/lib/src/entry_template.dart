import 'package:decimal/decimal.dart';
import 'package:domain/src/entry.dart';
import 'package:domain/src/holder_referencing.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/occurrence_id.dart';
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
  }) : categoryID = canonicalOptionalID(categoryID),
       sourceID = canonicalID(sourceID),
       destinationID = canonicalOptionalID(destinationID);

  @override
  final Decimal amount;
  final String name;
  final String? categoryID;

  @override
  final String sourceID;

  @override
  final String? destinationID;

  final bool includeInAnalysis;

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
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EntryTemplate &&
        other.amount == amount &&
        other.name == name &&
        other.categoryID == categoryID &&
        other.sourceID == sourceID &&
        other.destinationID == destinationID &&
        other.includeInAnalysis == includeInAnalysis;
  }

  @override
  int get hashCode => Object.hash(
    amount,
    name,
    categoryID,
    sourceID,
    destinationID,
    includeInAnalysis,
  );
}
