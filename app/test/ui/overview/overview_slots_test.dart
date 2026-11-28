import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_card_statement_mapping.dart';
import 'package:spendwise/ui/overview/overview_insights_mapping.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/overview/overview_top_categories_mapping.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

class _FakeOverviewViewModel implements OverviewViewModel {
  @override
  void clearStep() {}

  @override
  void openBudget(String budgetID) {}

  @override
  void openEntry(String id) {}

  @override
  void requestBudgets() {}

  @override
  void requestTrends() {}

  @override
  void requestEditOverview() {}

  @override
  void requestHistory() {}

  @override
  void retryReads() {}
}

final _day = DateTime.utc(2026, 5, 20);

OverviewViewState _viewState({
  OverviewInsights? insights,
  OverviewWeekSoFar? weekSoFar,
  bool insightsFailed = false,
  bool insightsSettledEmpty = false,
  List<OverviewCardStatementRow>? cardStatements,
  OverviewTopCategories? topCategories,
}) => OverviewViewState(
  day: _day,
  today: null,
  recent: null,
  upcoming: null,
  thisMonth: null,
  insights: insights,
  weekSoFar: weekSoFar,
  insightsFailed: insightsFailed,
  insightsSettledEmpty: insightsSettledEmpty,
  cardStatements: cardStatements,
  topCategories: topCategories,
);

void main() {
  const defaultKinds = [
    OverviewWidgetKind.today,
    OverviewWidgetKind.thisMonth,
    OverviewWidgetKind.recentEntries,
    OverviewWidgetKind.cardStatement,
    OverviewWidgetKind.comingUp,
    OverviewWidgetKind.budgetWatch,
    OverviewWidgetKind.insights,
    OverviewWidgetKind.weekSoFar,
  ];
  const cardKinds = [
    OverviewWidgetKind.today,
    OverviewWidgetKind.thisMonth,
    OverviewWidgetKind.recentEntries,
    OverviewWidgetKind.topCategories,
    OverviewWidgetKind.cardStatement,
    OverviewWidgetKind.comingUp,
    OverviewWidgetKind.budgetWatch,
    OverviewWidgetKind.insights,
    OverviewWidgetKind.weekSoFar,
  ];

  test('overviewCardKinds lists the card kinds in declaration order', () {
    expect(overviewCardKinds, cardKinds);
  });

  test('topCategories comes right after recentEntries', () {
    final recentIndex = overviewCardKinds.indexOf(
      OverviewWidgetKind.recentEntries,
    );
    expect(
      overviewCardKinds[recentIndex + 1],
      OverviewWidgetKind.topCategories,
    );
  });

  group('overviewCardFor topCategories', () {
    final viewModel = _FakeOverviewViewModel();
    final card = overviewCardFor(OverviewWidgetKind.topCategories);

    Widget? buildSlot(OverviewTopCategories? topCategories) =>
        card!.build(_viewState(topCategories: topCategories), viewModel);

    test('builds a widget while the read is pending', () {
      expect(buildSlot(null), isA<Widget>());
    });

    test('builds a widget with no rows', () {
      final empty = OverviewTopCategories(
        caption: 'May so far',
        rows: const [],
      );
      expect(buildSlot(empty), isA<Widget>());
    });

    test('builds a widget with rows', () {
      final withRows = OverviewTopCategories(
        caption: 'May so far',
        rows: const [
          OverviewTopCategoryRow(
            name: 'Food',
            symbolName: 'fork.knife',
            savedHex: null,
            amount: '10.00',
            barRatio: 1,
          ),
        ],
      );
      expect(buildSlot(withRows), isA<Widget>());
    });
  });

  group('overviewWidgetsOrDefault', () {
    test('an empty list becomes the defaults', () {
      expect(
        overviewWidgetsOrDefault(const []),
        DisplayPreferences.defaults.overviewWidgets,
      );
    });

    test('the defaults are the eight card kinds', () {
      expect(DisplayPreferences.defaults.overviewWidgets, defaultKinds);
    });

    test('a list with only cardless kinds becomes the defaults', () {
      expect(
        overviewWidgetsOrDefault(const [
          OverviewWidgetKind.accountBalances,
          OverviewWidgetKind.savingsPocket,
        ]),
        DisplayPreferences.defaults.overviewWidgets,
      );
    });

    test('a list with a card kind is returned unchanged', () {
      const stored = [
        OverviewWidgetKind.topCategories,
        OverviewWidgetKind.comingUp,
      ];
      expect(overviewWidgetsOrDefault(stored), stored);
    });

    test('a stored list without insights or weekSoFar does not gain them', () {
      const stored = [OverviewWidgetKind.today, OverviewWidgetKind.budgetWatch];
      expect(overviewWidgetsOrDefault(stored), stored);
    });
  });

  group('overviewSlotFor cardStatement', () {
    final viewModel = _FakeOverviewViewModel();

    test('is present while the read is pending', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.cardStatement,
        viewState: _viewState(),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });

    test('is present when no card owes anything', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.cardStatement,
        viewState: _viewState(cardStatements: const []),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });

    test('is present with rows', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.cardStatement,
        viewState: _viewState(
          cardStatements: const [
            OverviewCardStatementRow(
              cardName: 'Amex Card',
              payable: 'S\$399.60',
              daysToCut: '12 days',
              cutDate: 'Closes 15 October',
              cycleAmount: 'S\$285.10',
            ),
          ],
        ),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });
  });

  group('overviewSlotFor insights', () {
    final viewModel = _FakeOverviewViewModel();

    test('is null when settled empty without a failure', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.insights,
        viewState: _viewState(insightsSettledEmpty: true),
        viewModel: viewModel,
      );
      expect(slot, isNull);
    });

    test('is present when history is needed', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.insights,
        viewState: _viewState(insights: const OverviewInsightsHistoryNeeded()),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });

    test('is present when the read failed', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.insights,
        viewState: _viewState(insightsFailed: true),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });

    test('is present while the read is pending', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.insights,
        viewState: _viewState(),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });
  });

  group('overviewSlotFor weekSoFar', () {
    final viewModel = _FakeOverviewViewModel();

    test('is present when history is needed', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.weekSoFar,
        viewState: _viewState(weekSoFar: const OverviewWeekHistoryNeeded()),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });

    test('is present when available', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.weekSoFar,
        viewState: _viewState(
          weekSoFar: const OverviewWeekAvailable(
            range: 'Mon - Wed',
            total: '10.00',
            comparison: null,
            totalTone: null,
            usualNote: 'note',
          ),
        ),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });

    test('is present while the read is pending', () {
      final slot = overviewSlotFor(
        OverviewWidgetKind.weekSoFar,
        viewState: _viewState(),
        viewModel: viewModel,
      );
      expect(slot, isNotNull);
    });
  });
}
