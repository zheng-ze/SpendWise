import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/stats/trends/trends_breakdown_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 4);

void main() {
  test('starts on whole period and supports both scope transitions', () async {
    final harness = await readyHarness(
      ledger: seededTrendsLedger(_today),
      today: _today,
    );
    final subscription = harness.container.listen(
      trendsBreakdownScopeProvider,
      (_, _) {},
    );

    expect(
      harness.container.read(trendsBreakdownScopeProvider),
      TrendsBreakdownScope.wholePeriod,
    );

    harness.viewModel.setBreakdownScope(TrendsBreakdownScope.selectedPeriod);
    expect(
      harness.container.read(trendsBreakdownScopeProvider),
      TrendsBreakdownScope.selectedPeriod,
    );

    harness.viewModel.setBreakdownScope(TrendsBreakdownScope.wholePeriod);
    expect(
      harness.container.read(trendsBreakdownScopeProvider),
      TrendsBreakdownScope.wholePeriod,
    );
    subscription.close();
  });

  test('repeating the current scope emits no state change', () async {
    final harness = await readyHarness(
      ledger: seededTrendsLedger(_today),
      today: _today,
    );
    var changes = 0;
    final subscription = harness.container.listen(
      trendsBreakdownScopeProvider,
      (_, _) => changes++,
    );

    harness.viewModel.setBreakdownScope(TrendsBreakdownScope.wholePeriod);
    harness.viewModel.setBreakdownScope(TrendsBreakdownScope.selectedPeriod);
    harness.viewModel.setBreakdownScope(TrendsBreakdownScope.selectedPeriod);

    expect(changes, 1);
    subscription.close();
  });

  test(
    'scope actions leave intent and pending navigation steps unchanged',
    () async {
      final harness = await readyHarness(
        ledger: seededTrendsLedger(_today),
        today: _today,
      );
      final scopeSubscription = harness.container.listen(
        trendsBreakdownScopeProvider,
        (_, _) {},
      );
      harness.viewModel.requestCategoryDetail(0);
      final intent = harness.intent;
      final step = harness.step;

      harness.viewModel.setBreakdownScope(TrendsBreakdownScope.selectedPeriod);

      expect(harness.intent, same(intent));
      expect(harness.intent.followsCurrent, isTrue);
      expect(harness.step, same(step));
      scopeSubscription.close();
    },
  );

  test(
    'scope survives selection, paging, kind, mode, retry and preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = emptyTrendsLedger();
      addTrendsEntry(ledger, '-50', DateTime.utc(2025, 10, 4));
      addTrendsEntry(ledger, '-25', DateTime.utc(2026, 9, 4));
      final harness = await readyHarness(ledger: ledger, today: _today);
      final scopeSubscription = harness.container.listen(
        trendsBreakdownScopeProvider,
        (_, _) {},
      );
      harness.viewModel.setBreakdownScope(TrendsBreakdownScope.selectedPeriod);

      harness.viewModel.selectSlot(5);
      final beforePaging = harness.intent.spreadEnd;
      harness.viewModel.previousPage();
      expect(harness.intent.spreadEnd, lessThan(beforePaging));
      harness.viewModel.nextPage();
      expect(harness.intent.spreadEnd, beforePaging);
      harness.viewModel.setKind(TrendsKind.income);
      harness.viewModel.setMode(TrendsMode.year);
      harness.viewModel.retry();
      await harness.container
          .read(displayPreferencesProvider.notifier)
          .replace(
            DisplayPreferences(breakdownChart: BreakdownChart.categoryMap),
          );
      await harness.settle();

      expect(
        harness.container.read(trendsBreakdownScopeProvider),
        TrendsBreakdownScope.selectedPeriod,
      );
      scopeSubscription.close();
    },
  );

  test('fresh route state starts on whole period after disposal', () async {
    final first = await readyHarness(
      ledger: seededTrendsLedger(_today),
      today: _today,
    );
    final subscription = first.container.listen(
      trendsBreakdownScopeProvider,
      (_, _) {},
    );
    first.viewModel.setBreakdownScope(TrendsBreakdownScope.selectedPeriod);
    subscription.close();
    await first.settle();
    final freshSubscription = first.container.listen(
      trendsBreakdownScopeProvider,
      (_, _) {},
    );

    expect(
      first.container.read(trendsBreakdownScopeProvider),
      TrendsBreakdownScope.wholePeriod,
    );
    freshSubscription.close();
  });

  test('scope labels follow the selected month or year mode', () {
    expect(
      TrendsBreakdownScope.wholePeriod.label(TrendsMode.year),
      'Whole period',
    );
    expect(
      TrendsBreakdownScope.selectedPeriod.label(TrendsMode.month),
      'Selected month',
    );
    expect(
      TrendsBreakdownScope.selectedPeriod.label(TrendsMode.year),
      'Selected year',
    );
  });
}
