import 'dart:ui' show Color;

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'package:spendwise/ui/format/color_hex.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/entry_transfer_scope.dart';

const _unknownHolderLabel = 'Unknown';
const _uncategorizedSymbol = 'help_outline';
const _transferSymbol = 'swap_horiz';
const _transferChipColor = Color(0xFF8E8E93);

@immutable
class TransactionRow {
  const TransactionRow({
    required this.id,
    required this.title,
    required this.note,
    required this.accountLine,
    required this.symbolName,
    required this.color,
    required this.amount,
    required this.amountKind,
  });

  final String id;

  final String title;

  /// The entry's own typed name. Not a separate note field: `Entry` has none,
  /// and the title above always comes from the category instead.
  final String note;

  final String accountLine;
  final String symbolName;
  final Color color;

  final Decimal amount;

  final AmountKind amountKind;
}

TransactionRow transactionRow(
  Entry entry,
  LedgerState state, {
  Set<String>? scopeIDs,
}) {
  if (entry.isTransfer) return _transferRow(entry, state, scopeIDs);
  return _nonTransferRow(entry, state);
}

TransactionRow _nonTransferRow(Entry entry, LedgerState state) {
  final categoryID = entry.categoryID;
  final category = categoryID == null ? null : state.categories[categoryID];

  final title = category == null
      ? 'Uncategorized'
      : _categoryTitle(category, state);
  final symbolName = category?.symbol ?? _uncategorizedSymbol;
  final color = category == null
      ? colorHexFallback
      : parseColorHex(category.colorHex);

  return TransactionRow(
    id: entry.id,
    title: title,
    note: entry.name,
    accountLine: state.sourceName(entry.sourceID) ?? _unknownHolderLabel,
    symbolName: symbolName,
    color: color,
    amount: entry.amount,
    amountKind: entry.amount < Decimal.zero
        ? AmountKind.expense
        : AmountKind.income,
  );
}

TransactionRow _transferRow(
  Entry entry,
  LedgerState state,
  Set<String>? scopeIDs,
) {
  final source = state.sourceName(entry.sourceID) ?? _unknownHolderLabel;
  final destination =
      state.sourceName(entry.destinationID) ?? _unknownHolderLabel;

  return TransactionRow(
    id: entry.id,
    title: 'Transfer',
    note: entry.name,
    accountLine: '$source > $destination',
    symbolName: _transferSymbol,
    color: _transferChipColor,
    amount: entry.amount.abs(),
    amountKind: _transferAmountKind(entry, scopeIDs),
  );
}

AmountKind _transferAmountKind(Entry entry, Set<String>? scopeIDs) {
  if (scopeIDs == null) return AmountKind.transfer;

  return switch (entry.transferScopeSign(scopeIDs)) {
    TransferScopeSign.gain => AmountKind.income,
    TransferScopeSign.loss => AmountKind.expense,
    TransferScopeSign.neutral => AmountKind.transfer,
  };
}

String _categoryTitle(TransactionCategory category, LedgerState state) {
  final parentID = category.parentID;
  if (parentID == null) return category.name;

  final parent = state.categories[parentID];
  if (parent == null) return category.name;

  return '${parent.name}/${category.name}';
}
