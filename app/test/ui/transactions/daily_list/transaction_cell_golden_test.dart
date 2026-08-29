import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

void main() {
  testWidgets('transaction cell layout with note, income and expense rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final rows = [
      TransactionRow(
        id: 'e0000000-0000-0000-0000-000000000001',
        title: 'Food/Coffee',
        note: 'Latte with Sam',
        accountLine: 'Checking',
        symbolName: 'local_cafe',
        color: const Color(0xFFFF0000),
        amount: Decimal.parse('-4.50'),
        amountKind: AmountKind.expense,
      ),
      TransactionRow(
        id: 'e0000000-0000-0000-0000-000000000002',
        title: 'Uncategorized',
        note: '',
        accountLine: 'Savings',
        symbolName: 'help_outline',
        color: const Color(0xFF888888),
        amount: Decimal.parse('1200'),
        amountKind: AmountKind.income,
      ),
      TransactionRow(
        id: 'e0000000-0000-0000-0000-000000000003',
        title: 'Transfer',
        note: 'Move to savings',
        accountLine: 'Checking > Savings',
        symbolName: 'swap_horiz',
        color: const Color(0xFF8E8E93),
        amount: Decimal.parse('300'),
        amountKind: AmountKind.transfer,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [for (final row in rows) TransactionCell(row: row)],
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/transaction_cell.png'),
    );
  });
}
