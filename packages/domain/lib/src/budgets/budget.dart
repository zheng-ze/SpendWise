import 'package:decimal/decimal.dart';
import 'package:domain/src/ids.dart';
import 'package:meta/meta.dart';

// MARK: - Model

@immutable
class Budget {
  Budget({String? id, required this.categoryID, required this.limit})
    : id = normalizedOrNewID(id);

  final String id;
  final String? categoryID;
  final Decimal limit;

  @override
  bool operator ==(Object other) {
    return other is Budget &&
        other.id == id &&
        other.categoryID == categoryID &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(id, categoryID, limit);

  @override
  String toString() => 'Budget($id, $categoryID, $limit)';
}
