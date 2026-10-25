import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_cell.dart';
import 'package:spendwise/ui/transactions/daily_list/transaction_row.dart';

void main() {
  testWidgets('register highlight is painted on the record surface', (
    tester,
  ) async {
    var tapped = false;
    final cell = TransactionCell.register(
      row: TransactionRow(
        id: 'entry-id',
        title: 'Dining',
        note: 'Lunch',
        accountLine: 'Checking',
        symbolName: 'restaurant',
        color: Color(0xFF000000),
        amount: Decimal.parse('-12.50'),
        amountKind: AmountKind.expense,
      ),
      isLastInDay: true,
      onTap: () => tapped = true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSpendWiseTheme(Brightness.dark),
        home: Scaffold(body: cell),
      ),
    );

    final inkFinder = find.descendant(
      of: find.byType(InkWell),
      matching: find.byType(Ink),
    );
    expect(inkFinder, findsOneWidget);
    expect(
      find.ancestor(of: inkFinder, matching: find.byType(Material)),
      findsWidgets,
    );

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });
}
