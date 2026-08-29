import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/helpers/slices.dart';
import 'package:spendwise/ui/stats/donut/stats_legend.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  const foodID = 'a0000000-0000-0000-0000-000000000001';

  final foodSlice = Slice(
    bucketID: foodID,
    amount: dec('50'),
    fraction: dec('0.7'),
    name: 'Food',
    symbolName: 'restaurant',
    color: const Color(0xFFFF0000),
  );

  final uncategorizedSlice = Slice(
    bucketID: null,
    amount: dec('20'),
    fraction: dec('0.3'),
    name: 'Uncategorized',
    symbolName: 'help_outline',
    color: const Color(0xFF8E8E93),
  );

  final syntheticSlice = Slice(
    bucketID: syntheticTransferExpenseBucketID(AccountType.savings),
    amount: dec('10'),
    fraction: dec('0.1'),
    name: 'Savings transfers',
    symbolName: 'swap_horiz',
    color: const Color(0xFF8E8E93),
  );

  Future<void> pump(
    WidgetTester tester,
    List<Slice> slices,
    void Function(String) onTap,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatsLegend(slices: slices, onTapCategory: onTap),
        ),
      ),
    );
  }

  testWidgets('tapping a normal row invokes the callback with its bucket id', (
    tester,
  ) async {
    String? tapped;
    await pump(tester, [foodSlice], (id) => tapped = id);

    await tester.tap(find.text('Food'));
    await tester.pump();

    expect(tapped, foodID);
  });

  testWidgets('tapping the uncategorized row invokes nothing', (tester) async {
    var callCount = 0;
    await pump(tester, [uncategorizedSlice], (_) => callCount++);

    await tester.tap(find.text('Uncategorized'));
    await tester.pump();

    expect(callCount, 0);
  });

  testWidgets('the uncategorized row renders no chevron', (tester) async {
    await pump(tester, [foodSlice, uncategorizedSlice], (_) {});

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('tapping a synthetic slice invokes nothing', (tester) async {
    var callCount = 0;
    await pump(tester, [syntheticSlice], (_) => callCount++);

    await tester.tap(find.text('Savings transfers'));
    await tester.pump();

    expect(callCount, 0);
  });

  testWidgets('the synthetic row renders no chevron', (tester) async {
    await pump(tester, [foodSlice, syntheticSlice], (_) {});

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
