import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: buildSpendWiseTheme(brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  testWidgets('income and positive use the income token', (tester) async {
    late Color byKind;
    late Color bySign;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            byKind = AmountStyle.of(context, kind: AmountKind.income).color;
            bySign = AmountStyle.of(context, signedValue: dec('0.01')).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(byKind, const Color(0xFF28684F));
    expect(bySign, const Color(0xFF28684F));
  });

  testWidgets('expense and negative use the expense token', (tester) async {
    late Color byKind;
    late Color bySign;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            byKind = AmountStyle.of(context, kind: AmountKind.expense).color;
            bySign = AmountStyle.of(context, signedValue: dec('-0.01')).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(byKind, const Color(0xFF964B44));
    expect(bySign, const Color(0xFF964B44));
  });

  testWidgets('transfer and zero use the text token', (tester) async {
    late Color byKind;
    late Color byZero;
    late Color fallback;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            byKind = AmountStyle.of(context, kind: AmountKind.transfer).color;
            byZero = AmountStyle.of(context, signedValue: Decimal.zero).color;
            fallback = AmountStyle.of(context).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(byKind, const Color(0xFF25272A));
    expect(byZero, const Color(0xFF25272A));
    expect(fallback, const Color(0xFF25272A));
  });

  testWidgets('dark mode resolves the dark tokens', (tester) async {
    late Color income;
    late Color expense;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            income = AmountStyle.of(context, kind: AmountKind.income).color;
            expense = AmountStyle.of(context, kind: AmountKind.expense).color;
            return const SizedBox.shrink();
          },
        ),
        brightness: Brightness.dark,
      ),
    );

    expect(income, const Color(0xFFA4D5B5));
    expect(expense, const Color(0xFFEBAEA8));
  });

  testWidgets('a negative amount is never shown in the income colour', (
    tester,
  ) async {
    late Color negative;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            negative = AmountStyle.of(
              context,
              signedValue: dec('-167.40'),
            ).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(negative, isNot(const Color(0xFF28684F)));
    expect(negative, const Color(0xFF964B44));
  });
}
