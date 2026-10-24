import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

const _timeout = Duration(seconds: 10);
const _mainID = 'a0000000-0000-0000-0000-000000000001';
const _accountID = 'a0000000-0000-0000-0000-000000000002';
const _entryMarchID = 'a0000000-0000-0000-0000-000000000003';
const _entryAprilID = 'a0000000-0000-0000-0000-000000000004';
const _entryOctoberID = 'a0000000-0000-0000-0000-000000000005';
const _childID = 'a0000000-0000-0000-0000-000000000006';
const _entryEarlierID = 'a0000000-0000-0000-0000-000000000007';
const _entryFutureID = 'a0000000-0000-0000-0000-000000000008';

void main() {
  testWidgets(
    'initial incoming month is selected with its amount and entries',
    (tester) async {
      final fixture = await _openDetail(tester);
      final state = fixture.container
          .read(categoryDetailViewModelProvider(fixture.args))
          .value!;
      final trend = (state.body as CategoryDetailReadyBody).trend!;
      final selection = trend.selection!;

      expect(trend.selectedIndex, 9);
      expect(selection.headline.title, 'October 2026');
      expect(selection.headline.amount, '-S\$5.00');
      expect(selection.rows.map((row) => row.id), [_entryOctoberID]);
      expect(find.text('Entries'), findsNothing);
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(_timeout),
  );

  testWidgets('switching from month to year immediately selects year entries', (
    tester,
  ) async {
    final fixture = await _openDetail(tester);
    final viewModel = fixture.container.read(
      categoryDetailViewModelProvider(fixture.args).notifier,
    );

    viewModel.setTrendMode(TrendsMode.year);
    await _pumpReady(tester, fixture.container, fixture.args);

    final trend =
        (fixture.container
                    .read(categoryDetailViewModelProvider(fixture.args))
                    .value!
                    .body
                as CategoryDetailReadyBody)
            .trend!;
    final selection = trend.selection!;
    expect(trend.mode, TrendsMode.year);
    expect(selection.headline.title, '2026');
    expect(selection.headline.amount, '-S\$21.00');
    expect(selection.rows.map((row) => row.id), [
      _entryOctoberID,
      _entryAprilID,
      _entryMarchID,
    ]);
    await tester.pumpAndSettle();
  }, timeout: const Timeout(_timeout));

  testWidgets(
    'switching from year to month immediately selects month entries',
    (tester) async {
      final fixture = await _openDetail(tester, year: true);
      final initialTrend =
          (fixture.container
                      .read(categoryDetailViewModelProvider(fixture.args))
                      .value!
                      .body
                  as CategoryDetailReadyBody)
              .trend!;
      expect(
        initialTrend.bars[initialTrend.selectedIndex].semanticLabel,
        '2026',
      );
      expect(initialTrend.selection!.headline.title, '2026');
      expect(initialTrend.selection!.headline.amount, '-S\$21.00');
      expect(initialTrend.selection!.rows, hasLength(3));
      final viewModel = fixture.container.read(
        categoryDetailViewModelProvider(fixture.args).notifier,
      );

      viewModel.setTrendMode(TrendsMode.month);
      await _pumpReady(tester, fixture.container, fixture.args);

      final trend =
          (fixture.container
                      .read(categoryDetailViewModelProvider(fixture.args))
                      .value!
                      .body
                  as CategoryDetailReadyBody)
              .trend!;
      final selection = trend.selection!;
      expect(trend.mode, TrendsMode.month);
      expect(selection.headline.title, 'January 2026');
      expect(selection.headline.amount, '-S\$0.00');
      expect(selection.rows, isEmpty);
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(_timeout),
  );

  testWidgets(
    'paging and scope clamps keep selection on the highlighted period',
    (tester) async {
      final fixture = await _openDetail(tester);
      final viewModel = fixture.container.read(
        categoryDetailViewModelProvider(fixture.args).notifier,
      );
      viewModel.setTrendMode(TrendsMode.year);
      await _pumpReady(tester, fixture.container, fixture.args);

      viewModel.previousTrendPage();
      await _pumpReady(tester, fixture.container, fixture.args);

      var trend =
          (fixture.container
                      .read(categoryDetailViewModelProvider(fixture.args))
                      .value!
                      .body
                  as CategoryDetailReadyBody)
              .trend!;
      expect(trend.bars[trend.selectedIndex].semanticLabel, '2023');
      expect(trend.selection!.headline.title, '2023');
      expect(trend.selection!.rows.map((row) => row.id), [_entryEarlierID]);

      viewModel.previousTrendPage();
      await _pumpReady(tester, fixture.container, fixture.args);
      trend =
          (fixture.container
                      .read(categoryDetailViewModelProvider(fixture.args))
                      .value!
                      .body
                  as CategoryDetailReadyBody)
              .trend!;
      expect(trend.bars[trend.selectedIndex].semanticLabel, '2023');
      expect(trend.selection!.headline.title, '2023');

      viewModel.setScope(const DirectScope());
      await _pumpReady(tester, fixture.container, fixture.args);
      trend =
          (fixture.container
                      .read(categoryDetailViewModelProvider(fixture.args))
                      .value!
                      .body
                  as CategoryDetailReadyBody)
              .trend!;
      expect(trend.bars[trend.selectedIndex].semanticLabel, '2024');
      expect(trend.selection!.headline.title, '2024');
      expect(trend.selection!.rows, isEmpty);
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(_timeout),
  );

  testWidgets('tr-cat-trend selects a local period from the chart axis', (
    tester,
  ) async {
    final ledger = _ledger();
    final args = CategoryDetailArgs(
      mainID: _mainID,
      kind: CategoryKind.expense,
      isYearRange: false,
      initialDate: DateTime.utc(2026, 3, 23),
    );
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 3)),
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      categoryDetailViewModelProvider(args),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final app = MaterialApp(
      theme: buildSpendWiseTheme(Brightness.light),
      home: CategoryDetailScreen(args: args),
    );
    final scope = UncontrolledProviderScope(container: container, child: app);
    await tester.pumpWidget(scope);
    await _pumpReady(tester, container, args);

    final initial = container
        .read(categoryDetailViewModelProvider(args))
        .value!;
    final initialBody = initial.body as CategoryDetailReadyBody;
    expect(initial.detailDate, DateTime.utc(2026, 3));
    expect(initialBody.trend!.bars, hasLength(12));
    expect(initialBody.trend!.selection!.headline.amount, '-S\$10.00');
    expect(initialBody.trend!.selection!.rows.single.id, _entryMarchID);
    expect(find.bySemanticsLabel('April 2026'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('April 2026'));
    await _pumpReady(tester, container, args);

    final selected = container
        .read(categoryDetailViewModelProvider(args))
        .value!;
    final selectedBody = selected.body as CategoryDetailReadyBody;
    final result = selectedBody.trend!.selection!;
    expect(selected.detailDate, DateTime.utc(2026, 3));
    expect(result.headline.title, 'April 2026');
    expect(result.headline.sublabel, 'Food');
    expect(result.headline.amount, '-S\$6.00');
    expect(result.rows.map((row) => row.id), [_entryAprilID]);
    expect(result.rows.single.title, 'Lunch');
    expect(result.rows.single.note, isEmpty);
    expect(result.rows.single.accountLine, '6 Apr / Direct to Food / Checking');

    container
        .read(categoryDetailViewModelProvider(args).notifier)
        .nextTrendPage();
    await _pumpReady(tester, container, args);
    final nextYear = container
        .read(categoryDetailViewModelProvider(args))
        .value!;
    final nextYearBody = nextYear.body as CategoryDetailReadyBody;
    expect(nextYear.detailDate, DateTime.utc(2026, 3));
    expect(nextYearBody.trend!.selection!.headline.title, 'April 2027');
    expect(nextYearBody.trend!.selection!.headline.amount, '-S\$8.00');
    expect(nextYearBody.trend!.selection!.rows.map((row) => row.id), [
      _entryFutureID,
    ]);
    await tester.pumpAndSettle();
  }, timeout: const Timeout(_timeout));
}

Future<void> _pumpReady(
  WidgetTester tester,
  ProviderContainer container,
  CategoryDetailArgs args,
) async {
  const maxPumps = 100;
  for (var attempt = 0; attempt < maxPumps; attempt++) {
    final state = container.read(categoryDetailViewModelProvider(args)).value;
    if (state?.body case CategoryDetailReadyBody(trend: final trend?)
        when trend.bars.isNotEmpty) {
      await tester.pump();
      return;
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
  fail('Category detail did not produce a ready trend within $maxPumps pumps');
}

Future<_DetailFixture> _openDetail(
  WidgetTester tester, {
  bool year = false,
}) async {
  final args = CategoryDetailArgs(
    mainID: _mainID,
    kind: CategoryKind.expense,
    isYearRange: year,
    initialDate: DateTime.utc(2026, 10, 3),
  );
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(_ledger()),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 3)),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(
    categoryDetailViewModelProvider(args),
    (_, _) {},
  );
  addTearDown(subscription.close);
  final app = MaterialApp(
    theme: buildSpendWiseTheme(Brightness.light),
    home: CategoryDetailScreen(args: args),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await _pumpReady(tester, container, args);
  await tester.pumpAndSettle();
  return _DetailFixture(container: container, args: args);
}

class _DetailFixture {
  const _DetailFixture({required this.container, required this.args});

  final ProviderContainer container;
  final CategoryDetailArgs args;
}

Ledger _ledger() {
  final account = Account(
    id: _accountID,
    name: 'Checking',
    type: AccountType.checking,
  );
  final food = TransactionCategory(
    id: _mainID,
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#34C759',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );
  final march = Entry(
    id: _entryMarchID,
    amount: Decimal.parse('-10'),
    name: 'Breakfast',
    sourceID: _accountID,
    categoryID: _mainID,
    date: DateTime.utc(2026, 3, 5),
  );
  final april = Entry(
    id: _entryAprilID,
    amount: Decimal.parse('-6'),
    name: 'Lunch',
    sourceID: _accountID,
    categoryID: _mainID,
    date: DateTime.utc(2026, 4, 6),
  );
  final october = Entry(
    id: _entryOctoberID,
    amount: Decimal.parse('-5'),
    name: 'Dinner',
    sourceID: _accountID,
    categoryID: _mainID,
    date: DateTime.utc(2026, 10, 6),
  );
  final earlier = Entry(
    id: _entryEarlierID,
    amount: Decimal.parse('-7'),
    name: 'Market',
    sourceID: _accountID,
    categoryID: _childID,
    date: DateTime.utc(2023, 5, 6),
  );
  final future = Entry(
    id: _entryFutureID,
    amount: Decimal.parse('-8'),
    name: 'Future lunch',
    sourceID: _accountID,
    categoryID: _mainID,
    date: DateTime.utc(2027, 4, 6),
  );
  final child = TransactionCategory(
    id: _childID,
    name: 'Market',
    kind: CategoryKind.expense,
    colorHex: '#34C759',
    includeInAnalysis: true,
    parentID: _mainID,
    symbol: 'shopping_bag',
  );
  return Ledger(
    state: LedgerState(
      moneySources: {_accountID: MoneySource.account(account)},
      categories: {_mainID: food, _childID: child},
      entries: {
        _entryMarchID: march,
        _entryAprilID: april,
        _entryOctoberID: october,
        _entryEarlierID: earlier,
        _entryFutureID: future,
      },
    ),
  );
}
