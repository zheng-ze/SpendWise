import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail_view_model.dart';
import 'package:spendwise/ui/stats/category_scope.dart';

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

  ProviderContainer buildContainer(Ledger ledger) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
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

  test('build starts on the initial month with the All scope', () async {
    final container = buildContainer(buildLedger());

    final state = await container.read(
      categoryDetailViewModelProvider(args).future,
    );

    expect(state.detailDate, DateTime.utc(2026, 3));
    expect(state.scope, const AllScope());
    expect(state.kind, CategoryKind.expense);
    expect(state.mainCategory?.id, food.id);
    expect(state.children.map((c) => c.id), [hawker.id]);
  });

  test('setDate moves the detail date without changing the scope', () async {
    final container = buildContainer(buildLedger());
    await container.read(categoryDetailViewModelProvider(args).future);
    final viewModel = container.read(
      categoryDetailViewModelProvider(args).notifier,
    );

    viewModel.setScope(SubScope(hawker.id));
    viewModel.setDate(DateTime.utc(2026, 4, 1));

    final state = container.read(categoryDetailViewModelProvider(args)).value;
    expect(state?.detailDate, DateTime.utc(2026, 4));
    expect(state?.scope, isA<SubScope>());
    expect((state?.scope as SubScope).subID, hawker.id);
  });

  test('setScope narrows totals to only the matching bucket', () async {
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
    await container.read(categoryDetailViewModelProvider(args).future);
    final viewModel = container.read(
      categoryDetailViewModelProvider(args).notifier,
    );

    final allState = container
        .read(categoryDetailViewModelProvider(args))
        .value!;
    expect(allState.totals.scopeTotal, dec('14'));

    viewModel.setScope(SubScope(hawker.id));
    final scopedState = container
        .read(categoryDetailViewModelProvider(args))
        .value!;
    expect(scopedState.totals.scopeTotal, dec('10'));
    expect(scopedState.scope, isA<SubScope>());

    viewModel.setScope(const DirectScope());
    final directState = container
        .read(categoryDetailViewModelProvider(args))
        .value!;
    expect(directState.totals.scopeTotal, dec('4'));
  });
}
