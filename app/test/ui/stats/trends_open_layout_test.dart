import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_open_layout.dart';
import 'package:spendwise/ui/stats/trends/trends_shared_breakdown_card.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import 'trends_test_support.dart';

const _interactionTimeout = Duration(seconds: 5);
final _today = DateTime.utc(2026, 10, 4);
const _diningID = '77777777-7777-7777-7777-777777777777';

void main() {
  testWidgets(
    'open layout keeps both groups, controls, and category routing active',
    timeout: Timeout(_interactionTimeout),
    (tester) async {
      final harness = (await tester.runAsync(_rankedHarness))!;
      TrendsKind? changedKind;
      TrendsMode? changedMode;
      TrendsBreakdownScope? changedScope;
      int? selectedPeriodIndex;
      var previousPressed = false;
      var nextPressed = false;

      void onOpenCategory(int index, TrendsCategoryDetailSource source) {
        harness.viewModel.requestCategoryDetail(index, source: source);
      }

      final layout = TrendsOpenLayout(
        body: harness.ready,
        kind: TrendsKind.expense,
        scope: TrendsBreakdownScope.wholePeriod,
        onKindChanged: (kind) => changedKind = kind,
        onModeChanged: (mode) => changedMode = mode,
        onScopeChanged: (scope) => changedScope = scope,
        onPrevious: () => previousPressed = true,
        onNext: () => nextPressed = true,
        onSelectPeriod: (index) => selectedPeriodIndex = index,
        onOpenCategory: onOpenCategory,
      );
      final home = Scaffold(body: SingleChildScrollView(child: layout));
      final app = MaterialApp(
        theme: buildSpendWiseTheme(Brightness.light),
        home: home,
      );
      await tester.pumpWidget(app);

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Category averages'), findsOneWidget);
      expect(find.text('October 2026'), findsWidgets);

      await tester.tap(find.text('Income'));
      await tester.tap(find.text('Year by year'));
      await tester.tap(find.bySemanticsLabel('Previous'));
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.tap(find.bySemanticsLabel('November 2026'));
      await tester.pumpAndSettle();

      expect(changedKind, TrendsKind.income);
      expect(changedMode, TrendsMode.year);
      expect(previousPressed, isTrue);
      expect(nextPressed, isTrue);
      expect(selectedPeriodIndex, 10);

      final sharedBreakdown = find.byType(TrendsSharedBreakdownCard);
      final dining = find
          .descendant(of: sharedBreakdown, matching: find.text('Dining'))
          .last;
      await tester.ensureVisible(dining);
      await tester.tap(dining);
      await tester.pumpAndSettle();

      expect(
        harness.step,
        isA<TrendsCategoryDetailRequested>().having(
          (step) => step.args,
          'args',
          CategoryDetailArgs(
            mainID: _diningID,
            kind: CategoryKind.expense,
            isYearRange: false,
            initialDate: DateTime.utc(2026, 10),
          ),
        ),
      );

      await tester.tap(find.text('Selected month'));
      await tester.pumpAndSettle();
      expect(changedScope, TrendsBreakdownScope.selectedPeriod);
    },
  );
}

Future<TrendsHarness> _rankedHarness() async {
  final ledger = emptyTrendsLedger();
  ledger.addCategory(
    TransactionCategory(
      id: _diningID,
      name: 'Dining',
      kind: CategoryKind.expense,
      colorHex: '#FF0000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  addTrendsEntry(
    ledger,
    '-500',
    DateTime.utc(2026, 1, 10),
    categoryID: _diningID,
  );
  addTrendsEntry(
    ledger,
    '-1',
    DateTime.utc(2024, 11, 1),
    categoryID: foodCategoryID,
  );
  addTrendsEntry(
    ledger,
    '-300',
    DateTime.utc(2026, 9, 11),
    categoryID: foodCategoryID,
  );
  addTrendsEntry(
    ledger,
    '-100',
    DateTime.utc(2026, 10, 1),
    categoryID: foodCategoryID,
  );
  return readyHarness(ledger: ledger, today: _today);
}
