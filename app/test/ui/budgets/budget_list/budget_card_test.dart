import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/budgets/budget_list/budget_card.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

void main() {
  final category = TransactionCategory(
    id: 'c0000000-0000-0000-0000-00000000000a',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#FFCC00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  final budget = Budget(
    id: 'b0000000-0000-0000-0000-00000000000a',
    categoryID: category.id,
    limitEvents: [
      LimitEvent(
        effectiveFromMonth: null,
        value: Decimal.parse('100'),
        kind: LimitEventKind.defaultLimit,
      ),
    ],
    createdAtMonth: const YearMonth(2026, 1),
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required Brightness brightness,
    required String spent,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSpendWiseTheme(brightness),
        home: Scaffold(
          body: BudgetCard(
            budget: budget,
            month: const YearMonth(2026, 3),
            items: [
              AnalysisItem(
                bucketID: category.id,
                amount: Decimal.parse(spent),
                date: DateTime.utc(2026, 3, 5),
                kind: CategoryKind.expense,
              ),
            ],
            state: LedgerState(
              categories: {category.id: category},
              budgets: {budget.id: budget},
            ),
          ),
        ),
      ),
    );
  }

  Color labelColor(WidgetTester tester, Finder label) =>
      tester.widget<Text>(label).style!.color!;

  for (final brightness in Brightness.values) {
    testWidgets('the percentage over a light fill reads in dark ink in '
        '${brightness.name} mode', (tester) async {
      await pumpCard(tester, brightness: brightness, spent: '60');

      final labels = find.text('60%');
      expect(labels, findsNWidgets(2));
      final scheme = buildSpendWiseTheme(brightness).colorScheme;
      expect(labelColor(tester, labels.at(0)), scheme.onSurfaceVariant);
      expect(labelColor(tester, labels.at(1)), const Color(0xFF101112));
    });
  }

  testWidgets('the fill-coloured percentage is clipped to the filled share', (
    tester,
  ) async {
    await pumpCard(tester, brightness: Brightness.light, spent: '60');

    final fillLabel = find.text('60%').at(1);
    final clip = find.ancestor(of: fillLabel, matching: find.byType(ClipRect));
    final clipRect = tester.getRect(clip.first);
    final fill = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(Container),
    );
    final fillWidth = tester.getRect(fill).width;
    final clipper = tester.widget<ClipRect>(clip.first).clipper!;

    expect(clipper.getClip(clipRect.size).width, closeTo(fillWidth, 0.01));
    expect(tester.getRect(fillLabel).left, greaterThan(fillWidth));
  });
}
