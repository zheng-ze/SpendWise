import 'package:decimal/decimal.dart';
import 'package:domain/src/category_kind.dart';
import 'package:domain/src/holder_referencing.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:meta/meta.dart';

enum EntryKind { income, expense, transfer }

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
       date = date ?? DateTime.now(),
       categoryID = canonicalOptionalID(categoryID),
       sourceID = canonicalID(sourceID),
       destinationID = canonicalOptionalID(destinationID);

  final String id;
  final DateTime date;

  /// Signed. Income positive, expense negative. Stored transfers are positive.
  final Decimal amount;

  final String name;
  final String? categoryID;

  @override
  final String sourceID;

  @override
  final String? destinationID;

  final bool includeInAnalysis;
  final LifecycleState lifecycle;

  bool get isTransfer => destinationID != null;

  /// Zero is income by this formula, but zero amounts never pass validation.
  EntryKind get kind {
    if (isTransfer) return EntryKind.transfer;
    return amount < Decimal.zero ? EntryKind.expense : EntryKind.income;
  }

  CategoryKind? get expectedCategoryKind => switch (kind) {
    EntryKind.income => CategoryKind.income,
    EntryKind.expense => CategoryKind.expense,
    EntryKind.transfer => null,
  };

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
