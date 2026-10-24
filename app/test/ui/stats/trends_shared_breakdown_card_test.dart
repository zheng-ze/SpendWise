import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_shared_breakdown_card.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import 'trends_test_support.dart';

const _interactionTimeout = Duration(seconds: 5);
final _today = DateTime.utc(2026, 10, 4);
const _foodID = '33333333-3333-3333-3333-333333333333';
const _diningID = '77777777-7777-7777-7777-777777777777';

void main() {
  testWidgets(
    'scope changes rows, total label and category source',
    timeout: Timeout(_interactionTimeout),
    (tester) async {
      final harness = (await tester.runAsync(_rankedHarness))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSpendWiseTheme(Brightness.light),
          home: _CardHarness(
            body: harness.ready,
            onOpenCategory: (index, source) =>
                harness.viewModel.requestCategoryDetail(index, source: source),
          ),
        ),
      );

      expect(find.text('Whole period'), findsOneWidget);
      expect(find.text('Whole displayed range'), findsOneWidget);
      expect(find.text('-S\$900.00'), findsOneWidget);
      expect(find.text('Dining'), findsWidgets);
      await tester.tap(find.text('Dining').last);
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
      harness.viewModel.clearStep();

      await tester.tap(find.text('Selected month'));
      await tester.pumpAndSettle();

      expect(find.text('Selected month'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('-S\$100.00'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      expect(
        harness.step,
        isA<TrendsCategoryDetailRequested>().having(
          (step) => step.args,
          'args',
          CategoryDetailArgs(
            mainID: _foodID,
            kind: CategoryKind.expense,
            isYearRange: false,
            initialDate: DateTime.utc(2026, 10),
          ),
        ),
      );
    },
  );

  testWidgets(
    'scope control names the selected year in year mode',
    timeout: Timeout(_interactionTimeout),
    (tester) async {
      final harness = (await tester.runAsync(_rankedHarness))!;
      await tester.runAsync(() async {
        harness.viewModel.setMode(TrendsMode.year);
        await harness.settle();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSpendWiseTheme(Brightness.light),
          home: _CardHarness(body: harness.ready),
        ),
      );

      expect(find.text('Selected year'), findsOneWidget);
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
    '-300',
    DateTime.utc(2026, 9, 11),
    categoryID: _foodID,
  );
  addTrendsEntry(
    ledger,
    '-100',
    DateTime.utc(2026, 10, 1),
    categoryID: _foodID,
  );
  return readyHarness(ledger: ledger, today: _today);
}

class _CardHarness extends StatefulWidget {
  const _CardHarness({required this.body, this.onOpenCategory});

  final TrendsReadyBody body;
  final void Function(int, TrendsCategoryDetailSource)? onOpenCategory;

  @override
  State<_CardHarness> createState() => _CardHarnessState();
}

class _CardHarnessState extends State<_CardHarness> {
  TrendsBreakdownScope _scope = TrendsBreakdownScope.wholePeriod;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TrendsSharedBreakdownCard(
      body: widget.body,
      scope: _scope,
      onScopeChanged: (scope) => setState(() => _scope = scope),
      onOpenCategory: (index, source) =>
          widget.onOpenCategory?.call(index, source),
    ),
  );
}
