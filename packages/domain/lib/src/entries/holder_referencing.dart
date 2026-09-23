import 'package:decimal/decimal.dart';
import 'package:domain/src/entries/category_kind.dart';

enum EntryKind { income, expense, transfer }

mixin HolderReferencing {
  String get sourceID;
  String? get destinationID;
  Decimal get amount;

  Set<String> get holderIDs => {sourceID, ?destinationID};

  bool references(String id) => sourceID == id || destinationID == id;

  bool touches(Set<String> ids) => holderIDs.intersection(ids).isNotEmpty;

  bool get isTransfer => destinationID != null;

  EntryKind get kind {
    if (isTransfer) return EntryKind.transfer;
    return amount < Decimal.zero ? EntryKind.expense : EntryKind.income;
  }

  CategoryKind? get expectedCategoryKind => switch (kind) {
    EntryKind.income => CategoryKind.income,
    EntryKind.expense => CategoryKind.expense,
    EntryKind.transfer => null,
  };
}
