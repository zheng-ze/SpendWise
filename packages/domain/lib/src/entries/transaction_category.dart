import 'package:domain/src/entries/category_kind.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:meta/meta.dart';

@immutable
class TransactionCategory {
  TransactionCategory({
    String? id,
    required this.name,
    required this.kind,
    required this.colorHex,
    required this.includeInAnalysis,
    required String? parentID,
    required this.symbol,
    this.lifecycle = LifecycleState.active,
  }) : id = normalizedOrNewID(id),
       parentID = normalizedOptionalID(parentID);

  final String id;
  final String name;
  final CategoryKind kind;
  final String colorHex;
  final bool includeInAnalysis;

  /// One level of nesting only, enforced by the validator.
  final String? parentID;

  final String symbol;
  final LifecycleState lifecycle;

  TransactionCategory settingLifecycle(LifecycleState lifecycle) {
    return TransactionCategory(
      id: id,
      name: name,
      kind: kind,
      colorHex: colorHex,
      includeInAnalysis: includeInAnalysis,
      parentID: parentID,
      symbol: symbol,
      lifecycle: lifecycle,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionCategory &&
        other.id == id &&
        other.name == name &&
        other.kind == kind &&
        other.colorHex == colorHex &&
        other.includeInAnalysis == includeInAnalysis &&
        other.parentID == parentID &&
        other.symbol == symbol &&
        other.lifecycle == lifecycle;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    colorHex,
    includeInAnalysis,
    parentID,
    symbol,
    lifecycle,
  );
}
