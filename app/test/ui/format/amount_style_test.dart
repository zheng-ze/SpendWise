import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/ui_test_timeout.dart';

void main() {
  testWidgets('negative signed values stay expense-colored for every kind', (
    tester,
  ) async {
    late Color negativeIncome;
    late Color negativeTransfer;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSpendWiseTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            negativeIncome = AmountStyle.of(
              context,
              kind: AmountKind.income,
              signedValue: Decimal.parse('-167.40'),
            ).color;
            negativeTransfer = AmountStyle.of(
              context,
              kind: AmountKind.transfer,
              signedValue: Decimal.parse('-167.40'),
            ).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(negativeIncome, const Color(0xFF964B44));
    expect(negativeTransfer, const Color(0xFF964B44));
  }, timeout: uiTestTimeout);
}
