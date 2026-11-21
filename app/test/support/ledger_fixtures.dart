import 'package:domain/domain.dart';

Account testAccount({
  String? id,
  String name = 'acc',
  AccountType type = AccountType.savings,
  LifecycleState lifecycle = LifecycleState.active,
}) {
  return Account(id: id, name: name, type: type, lifecycle: lifecycle);
}

TransactionCategory testCategory({
  String? id,
  required String name,
  CategoryKind kind = CategoryKind.expense,
  String colorHex = '#000000',
  bool includeInAnalysis = true,
  String? parentID,
  String symbol = 'tag',
  LifecycleState lifecycle = LifecycleState.active,
}) {
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

Entry testEntry({
  String? id,
  required String sourceID,
  Decimal? amount,
  String name = 'entry',
  String? categoryID,
  String? destinationID,
  DateTime? date,
  bool includeInAnalysis = true,
}) {
  return Entry(
    id: id,
    date: date,
    amount: amount ?? Decimal.fromInt(-10),
    name: name,
    categoryID: categoryID,
    sourceID: sourceID,
    destinationID: destinationID,
    includeInAnalysis: includeInAnalysis,
  );
}
