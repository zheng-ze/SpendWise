import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

const _readyTimeout = Duration(seconds: 5);
const _maxReadyPumps = 100;

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  final food = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000001',
    name: 'Food',
    kind: CategoryKind.expense,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'restaurant',
  );

  final hawker = TransactionCategory(
    id: 'c0000000-0000-0000-0000-000000000002',
    name: 'Hawker',
    kind: CategoryKind.expense,
    colorHex: '#00BB00',
    includeInAnalysis: true,
    parentID: food.id,
    symbol: 'set_meal',
  );

  Ledger buildLedger({Map<String, Entry> entries = const {}}) {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food, hawker.id: hawker},
        entries: entries,
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger, {ComputeRunner? runner}) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 23)),
        analysisComputeRunnerProvider.overrideWithValue(
          runner ?? syncComputeRunner,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final args = CategoryDetailArgs(
    mainID: food.id,
    kind: CategoryKind.expense,
    isYearRange: false,
    initialDate: DateTime.utc(2026, 3, 15),
  );

  Future<CategoryDetailViewState> openDetail(
    ProviderContainer container,
  ) async {
    final provider = categoryDetailViewModelProvider(args);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    return waitForDetail(container, args).timeout(_readyTimeout);
  }

  test('tr-cat opens the supplied month with the All scope', () async {
    final container = buildContainer(buildLedger());

    final state = await openDetail(container);

    expect(state.detailDate, DateTime.utc(2026, 3));
    expect(state.scope, const AllScope());
    expect(state.kind, CategoryKind.expense);
    final body = state.body as CategoryDetailReadyBody;
    expect(state.subtitle, 'March 2026');
    expect(body.mainCategory?.id, food.id);
    expect(body.children.map((c) => c.id), [hawker.id]);
    expect(body.trend!.selection!.headline.title, 'March 2026');
    expect(body.trend!.selection!.headline.amount, '-S\$0.00');
  });

  test(
    'mode changes keep highlighting the immutable incoming period',
    () async {
      final earlier = Entry(
        amount: dec('-5'),
        name: 'Earlier',
        sourceID: account.id,
        categoryID: food.id,
        date: DateTime.utc(2024, 6, 1),
      );
      final incoming = Entry(
        amount: dec('-8'),
        name: 'Incoming month',
        sourceID: account.id,
        categoryID: hawker.id,
        date: DateTime.utc(2026, 3, 5),
      );
      final container = buildContainer(
        buildLedger(entries: {earlier.id: earlier, incoming.id: incoming}),
      );
      await openDetail(container);
      final viewModel = container.read(
        categoryDetailViewModelProvider(args).notifier,
      );

      viewModel.setTrendMode(TrendsMode.year);
      final yearState = await waitForTrend(
        container,
        args,
        TrendsMode.year,
        '2026',
      );
      final yearTrend = (yearState.body as CategoryDetailReadyBody).trend!;

      expect(yearState.detailDate, DateTime.utc(2026, 3));
      expect(yearTrend.bars[yearTrend.selectedIndex].semanticLabel, '2026');
      expect(yearTrend.selection!.headline.title, '2026');
      expect(yearTrend.selection!.headline.amount, '-S\$8.00');
      expect(yearTrend.selection!.rows.single.id, incoming.id);

      viewModel.setTrendMode(TrendsMode.month);
      final monthState = await waitForTrend(
        container,
        args,
        TrendsMode.month,
        'March 2026',
      );
      final monthTrend = (monthState.body as CategoryDetailReadyBody).trend!;

      expect(monthState.detailDate, DateTime.utc(2026, 3));
      expect(
        monthTrend.bars[monthTrend.selectedIndex].semanticLabel,
        'March 2026',
      );
      expect(monthTrend.selection!.headline.title, 'March 2026');
      expect(monthTrend.selection!.headline.amount, '-S\$8.00');
      expect(monthTrend.selection!.rows.single.id, incoming.id);
    },
  );

  test(
    'tr-cat-direct changes scope without moving the incoming period',
    () async {
      final container = buildContainer(buildLedger());
      await openDetail(container);
      final viewModel = container.read(
        categoryDetailViewModelProvider(args).notifier,
      );

      viewModel.setScope(const DirectScope());

      final state = await waitForDetail(container, args);
      final body = state.body as CategoryDetailReadyBody;
      expect(state.detailDate, DateTime.utc(2026, 3));
      expect(state.scope, const DirectScope());
      expect(body.totals.scopeTotal, Decimal.zero);
      expect(body.sections, isEmpty);
      expect(body.chips.last.scope, const DirectScope());
      expect(body.chips.last.selected, isTrue);
    },
  );

  test('tr-cat-sub narrows totals and entries to the matching child', () async {
    final hawkerEntry = Entry(
      amount: dec('-10'),
      name: 'Noodles',
      sourceID: account.id,
      categoryID: hawker.id,
      date: DateTime.utc(2026, 3, 5),
    );
    final directEntry = Entry(
      amount: dec('-4'),
      name: 'Groceries',
      sourceID: account.id,
      categoryID: food.id,
      date: DateTime.utc(2026, 3, 6),
    );
    final ledger = buildLedger(
      entries: {hawkerEntry.id: hawkerEntry, directEntry.id: directEntry},
    );
    final container = buildContainer(ledger);
    await openDetail(container);
    final viewModel = container.read(
      categoryDetailViewModelProvider(args).notifier,
    );

    final allState = await waitForDetail(container, args);
    final allBody = allState.body as CategoryDetailReadyBody;
    expect(allBody.totals.scopeTotal, dec('14'));

    viewModel.setScope(SubScope(hawker.id));
    final scopedState = await waitForDetail(container, args);
    final scopedBody = scopedState.body as CategoryDetailReadyBody;
    expect(scopedBody.totals.scopeTotal, dec('10'));
    expect(scopedBody.sections.single.rows.single.id, hawkerEntry.id);
    expect(scopedBody.sections.single.rows.single.title, 'Noodles');
    expect(scopedBody.sections.single.rows.single.note, isEmpty);
    expect(
      scopedBody.sections.single.rows.single.accountLine,
      isNot(contains('Mar')),
    );
    expect(scopedState.scope, isA<SubScope>());

    viewModel.setScope(const DirectScope());
    final directState = await waitForDetail(container, args);
    final directBody = directState.body as CategoryDetailReadyBody;
    expect(directBody.totals.scopeTotal, dec('4'));
    expect(directBody.sections.single.rows.single.id, directEntry.id);
  });

  test('failed loading retries the current query and preserves child scope and period', () async {
    final entry = Entry(
      amount: dec('-8'),
      name: 'Lunch',
      sourceID: account.id,
      categoryID: hawker.id,
      date: DateTime.utc(2026, 3, 5),
    );
    final ledger = buildLedger(entries: {entry.id: entry});
    final first = Completer<List<AnalysisItem>>();
    final replacement = Completer<List<AnalysisItem>>();
    var calls = 0;
    Future<List<AnalysisItem>> runner(LedgerState state) {
      calls += 1;
      return calls == 1 ? first.future : replacement.future;
    }

    final container = buildContainer(ledger, runner: runner);
    final provider = categoryDetailViewModelProvider(args);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final viewModel = container.read(provider.notifier);
    viewModel.setScope(SubScope(hawker.id));

    final loading = await waitForBody<CategoryDetailLoadingBody>(
      container,
      args,
    );
    expect((loading.scope as SubScope).subID, hawker.id);
    expect(loading.detailDate, DateTime.utc(2026, 3));
    expect(calls, 1);
    first.completeError(StateError('analysis unavailable'));

    final failed = await waitForBody<CategoryDetailErrorBody>(container, args);
    expect((failed.scope as SubScope).subID, hawker.id);
    viewModel.retry();

    final retrying = await waitForBody<CategoryDetailLoadingBody>(
      container,
      args,
    );
    expect((retrying.scope as SubScope).subID, hawker.id);
    expect(retrying.detailDate, DateTime.utc(2026, 3));
    expect(calls, 2);
    replacement.complete(Accounting.analysisItems(ledger.state));

    final ready = await waitForDetail(container, args);
    final body = ready.body as CategoryDetailReadyBody;
    expect((ready.scope as SubScope).subID, hawker.id);
    expect(ready.detailDate, DateTime.utc(2026, 3));
    expect(body.totals.scopeTotal, dec('8'));
    expect(body.sections.single.rows.single.id, entry.id);
    expect(calls, 2);
  }, timeout: const Timeout(_readyTimeout));
}

Future<CategoryDetailViewState> waitForBody<T extends CategoryDetailBody>(
  ProviderContainer container,
  CategoryDetailArgs args,
) async {
  for (var attempt = 0; attempt < _maxReadyPumps; attempt++) {
    final state = container.read(categoryDetailViewModelProvider(args)).value;
    if (state != null && state.body is T) return state;
    await Future<void>.delayed(Duration.zero);
  }
  throw TimeoutException('Detail did not reach $T', _readyTimeout);
}

Future<CategoryDetailViewState> waitForDetail(
  ProviderContainer container,
  CategoryDetailArgs args,
) async {
  for (var attempt = 0; attempt < _maxReadyPumps; attempt++) {
    final state = container.read(categoryDetailViewModelProvider(args)).value;
    final revision = container.read(ledgerSessionProvider)?.ledger.revision;
    final body = state?.body;
    if (body is CategoryDetailReadyBody && body.sourceRevision == revision) {
      return state!;
    }
    await Future<void>.delayed(Duration.zero);
  }
  throw TimeoutException(
    'Detail did not reach the current revision',
    _readyTimeout,
  );
}

Future<CategoryDetailViewState> waitForTrend(
  ProviderContainer container,
  CategoryDetailArgs args,
  TrendsMode mode,
  String highlightedPeriod,
) async {
  for (var attempt = 0; attempt < _maxReadyPumps; attempt++) {
    final state = container.read(categoryDetailViewModelProvider(args)).value;
    final body = state?.body;
    final trend = body is CategoryDetailReadyBody ? body.trend : null;
    final index = trend?.selectedIndex ?? -1;
    final highlightMatches =
        trend != null &&
        index >= 0 &&
        index < trend.bars.length &&
        trend.bars[index].semanticLabel == highlightedPeriod;
    if (trend?.mode == mode && highlightMatches) return state!;
    await Future<void>.delayed(Duration.zero);
  }
  throw TimeoutException(
    'Trend did not highlight $highlightedPeriod in $mode mode',
    _readyTimeout,
  );
}
