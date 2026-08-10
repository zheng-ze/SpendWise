import 'package:domain/domain.dart';

Account account(
  String id, {
  String name = 'acc',
  AccountType type = AccountType.savings,
  Set<String> subPocketIDs = const {},
  bool incomingTransfersAsExpenses = false,
  bool includeInNetWorth = true,
  int? statementDay,
  LifecycleState lifecycle = LifecycleState.active,
}) => Account(
  id: id,
  name: name,
  type: type,
  subPocketIDs: subPocketIDs,
  incomingTransfersAsExpenses: incomingTransfersAsExpenses,
  includeInNetWorth: includeInNetWorth,
  statementDay: statementDay,
  lifecycle: lifecycle,
);

SubPocket pocket(
  String id, {
  String name = 'pkt',
  bool incomingTransfersAsExpenses = false,
  LifecycleState lifecycle = LifecycleState.active,
}) => SubPocket(
  id: id,
  name: name,
  incomingTransfersAsExpenses: incomingTransfersAsExpenses,
  lifecycle: lifecycle,
);

TransactionCategory category(
  String id, {
  String name = 'cat',
  CategoryKind kind = CategoryKind.expense,
  String? parent,
  String colorHex = '#888888',
  bool includeInAnalysis = true,
  String symbol = 'tag',
  LifecycleState lifecycle = LifecycleState.active,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  colorHex: colorHex,
  includeInAnalysis: includeInAnalysis,
  parentID: parent,
  symbol: symbol,
  lifecycle: lifecycle,
);

Entry entry({
  String? id,
  DateTime? date,
  Decimal? amount,
  String name = 'e',
  String? categoryID,
  required String sourceID,
  String? destinationID,
  bool includeInAnalysis = true,
}) => Entry(
  id: id,
  date: date ?? DateTime.utc(2026),
  amount: amount ?? Decimal.fromInt(-10),
  name: name,
  categoryID: categoryID,
  sourceID: sourceID,
  destinationID: destinationID,
  includeInAnalysis: includeInAnalysis,
);

String uuid(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
