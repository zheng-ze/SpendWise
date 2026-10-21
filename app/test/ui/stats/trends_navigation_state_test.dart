import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

import '../../ledger/analysis_test_support.dart';
import 'trends_test_support.dart';

final _today = DateTime.utc(2026, 10, 3);
final _itemDate = DateTime.utc(2026, 10, 2);

const _unknownBucket = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _syntheticBucket = 'transfer-expense:savings';
const _itemAmount = '10';

CategoryDetailArgs _requested(TrendsStep? step) {
  if (step is TrendsCategoryDetailRequested) return step.args;
  throw StateError('Expected a category detail request, found $step');
}

void _addDining(Ledger ledger, DateTime date) {
  ledger.addEntry(
    Entry(
      amount: Decimal.fromInt(-5),
      name: 'Dinner',
      sourceID: ledger.state.activeAccounts.first.id,
      categoryID: _categoryID(ledger, 'Dining'),
      date: date,
    ),
  );
}

String _categoryID(Ledger ledger, String name) =>
    ledger.state.categories.values.singleWhere((c) => c.name == name).id;

AnalysisItem _item(String? bucketID) => AnalysisItem(
  kind: CategoryKind.expense,
  amount: Decimal.parse(_itemAmount),
  date: _itemDate,
  bucketID: bucketID,
);

Future<TrendsHarness> _controlled(List<String?> buckets) async {
  final ledger = emptyTrendsLedger();
  addTrendsEntry(ledger, '-1', _today);
  final items = [for (final bucket in buckets) _item(bucket)];
  final harness = TrendsHarness(
    ledger: ledger,
    today: _today,
    runner: (_) async => items,
  );
  await harness.settle();
  return harness;
}

Future<TrendsHarness> _seeded({DisplayPreferences? preferences}) async {
  final harness = TrendsHarness(
    ledger: seededTrendsLedger(_today),
    today: _today,
    preferences: preferences,
  );
  await harness.settle();
  return harness;
}

void main() {
  group('category detail requests', () {
    test('a ranked row requests the unchanged detail args', () async {
      final harness = await _seeded();

      harness.viewModel.requestCategoryDetail(0);

      expect(
        _requested(harness.step),
        CategoryDetailArgs(
          mainID: _categoryID(harness.ledger, 'Dining'),
          kind: CategoryKind.expense,
          isYearRange: false,
          initialDate: DateTime.utc(2026, 10),
        ),
      );
    });

    test('income and year mode map into the args', () async {
      final harness = await _seeded();
      harness.viewModel.setKind(TrendsKind.income);
      harness.viewModel.setMode(TrendsMode.year);
      await harness.settle();

      harness.viewModel.requestCategoryDetail(0);

      expect(
        _requested(harness.step),
        CategoryDetailArgs(
          mainID: _categoryID(harness.ledger, 'Salary'),
          kind: CategoryKind.income,
          isYearRange: true,
          initialDate: DateTime.utc(2026),
        ),
      );
    });

    test('the args carry the effective selected period', () async {
      final harness = await _seeded();
      _addDining(harness.ledger, DateTime.utc(2026, 7, 10));
      await harness.settle();
      final july = harness.ready.bars.indexWhere(
        (bar) => bar.semanticLabel == 'July 2026',
      );
      harness.viewModel.selectSlot(july);
      await harness.settle();

      harness.viewModel.requestCategoryDetail(0);

      expect(_requested(harness.step).initialDate, DateTime.utc(2026, 7));
    });

    test('subcategory and Direct rows open their main category', () async {
      final harness = await _seeded(
        preferences: DisplayPreferences(
          breakdownLevel: BreakdownLevel.subcategories,
        ),
      );
      final groceries = _categoryID(harness.ledger, 'Groceries');
      final rows = harness.ready.breakdown.rows;
      final children = [
        for (var i = 0; i < rows.length; i++)
          if (rows[i].parentContext == 'Groceries') i,
      ];

      expect(children, hasLength(3));
      for (final index in children) {
        harness.viewModel.requestCategoryDetail(index);
        expect(_requested(harness.step).mainID, groceries);
        harness.viewModel.clearStep();
      }
    });

    test('Uncategorized and synthetic buckets are inert', () async {
      final harness = await _controlled([null, _syntheticBucket]);

      for (
        var index = 0;
        index < harness.ready.breakdown.rows.length;
        index++
      ) {
        harness.viewModel.requestCategoryDetail(index);
      }

      expect(harness.ready.breakdown.rows, hasLength(2));
      expect(harness.step, isNull);
    });

    test('an unresolved non-null bucket stays navigable', () async {
      final harness = await _controlled([null, _unknownBucket]);
      final rows = harness.ready.breakdown.rows;
      final index = rows.indexWhere((row) => row.bucketID == _unknownBucket);

      harness.viewModel.requestCategoryDetail(index);

      expect(rows[index].name, 'Uncategorized');
      expect(_requested(harness.step).mainID, _unknownBucket);
    });

    test('invalid indices are ignored', () async {
      final harness = await _seeded();
      final count = harness.ready.breakdown.rows.length;

      harness.viewModel.requestCategoryDetail(-1);
      harness.viewModel.requestCategoryDetail(count);

      expect(harness.step, isNull);
    });

    test('requests outside ready data are ignored', () async {
      final runner = ManualRunner();
      final harness = TrendsHarness(
        ledger: seededTrendsLedger(_today),
        today: _today,
        runner: runner.call,
      );
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());

      harness.viewModel.requestCategoryDetail(0);

      expect(harness.step, isNull);
    });

    test('a request after disposal is ignored', () async {
      final harness = await _seeded();
      final viewModel = harness.viewModel;
      harness.dispose();

      expect(() => viewModel.requestCategoryDetail(0), returnsNormally);
    });
  });

  group('pending step', () {
    test(
      'survives clock, preference and ledger rebuilds until cleared',
      () async {
        SharedPreferences.setMockInitialValues({});
        final harness = await _seeded();
        harness.viewModel.requestCategoryDetail(0);
        final pending = harness.step;
        expect(pending, isNotNull);

        await harness.setToday(DateTime.utc(2026, 10, 4));
        expect(harness.step, same(pending));

        await harness.container
            .read(displayPreferencesProvider.notifier)
            .replace(
              DisplayPreferences(breakdownChart: BreakdownChart.categoryMap),
            );
        await harness.settle();
        expect(harness.step, same(pending));

        _addDining(harness.ledger, _today);
        await harness.settle();
        expect(harness.step, same(pending));

        harness.viewModel.clearStep();
        expect(harness.step, isNull);
        await harness.setToday(DateTime.utc(2026, 10, 5));
        expect(harness.step, isNull);
      },
    );

    test('a repeated request publishes a new step instance', () async {
      final harness = await _seeded();
      harness.viewModel.requestCategoryDetail(0);
      final first = harness.step;

      harness.viewModel.requestCategoryDetail(0);

      expect(harness.step, isNot(same(first)));
      expect(harness.step, isA<TrendsCategoryDetailRequested>());
    });
  });
}
