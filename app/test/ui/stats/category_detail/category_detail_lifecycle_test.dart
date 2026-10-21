import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';

import '../../../ledger/analysis_test_support.dart';
import '../../../support/counting_ledger_session.dart';
import '../../../support/ui_test_timeout.dart';

void main() {
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
  final args = CategoryDetailArgs(
    mainID: food.id,
    kind: CategoryKind.expense,
    isYearRange: false,
    initialDate: DateTime.utc(2026, 3, 15),
  );
  Entry lunch(String amount) => Entry(
    amount: Decimal.parse(amount),
    name: 'Lunch',
    sourceID: account.id,
    categoryID: food.id,
    date: DateTime.utc(2026, 3, 5),
  );

  Counted counted({
    ComputeRunner runner = syncComputeRunner,
    Map<String, Entry> entries = const {},
  }) {
    return countedSession(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
        entries: entries,
      ),
      runner: runner,
    );
  }

  Future<void> pumpRoute(WidgetTester tester, ProviderContainer container) {
    MaterialPageRoute<void> detailRoute() => MaterialPageRoute<void>(
      builder: (_) => CategoryDetailScreen(args: args),
    );
    final home = Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(detailRoute()),
        child: const Text('open'),
      ),
    );
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: home),
      ),
    );
  }

  testWidgets(
    'closing the route releases listeners and reopening still updates',
    (tester) async {
      final env = counted();
      final container = containerFor(() => env.session);
      final baselineLedger = env.ledger.listeners;
      final baselineCache = env.cache.listeners;
      await pumpRoute(tester, container);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(env.ledger.listeners, baselineLedger + 1);
      expect(env.cache.listeners, baselineCache + 1);

      Navigator.of(tester.element(find.byType(CategoryDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(env.ledger.listeners, baselineLedger);
      expect(env.cache.listeners, baselineCache);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      env.ledger.addEntry(lunch('-12'));
      await tester.pumpAndSettle();
      expect(find.text('S\$12.00'), findsWidgets);
    },
    timeout: uiTestTimeout,
  );

  test(
    'closing during a delayed refresh then mutating the ledger is inert',
    () async {
      final runner = ManualRunner();
      final env = counted(runner: runner.call);
      final container = containerFor(() => env.session);
      final subscription = container.listen(
        categoryDetailViewModelProvider(args),
        (_, _) {},
      );

      await pumpEventQueue();
      expect(runner.pending, hasLength(1));
      subscription.close();
      await pumpEventQueue();
      env.ledger.addEntry(lunch('-3'));
      runner.pending.single.complete(const []);
      await pumpEventQueue();

      expect(env.ledger.listeners, 0);
      expect(env.cache.listeners, 0);
    },
    timeout: uiTestTimeout,
  );

  test(
    'session replacement ignores the old instances and rebuilds on the new',
    () async {
      final oldRunner = ManualRunner();
      final old = counted(runner: oldRunner.call);
      final replacement = counted(entries: {lunch('-7').id: lunch('-7')});
      final container = containerFor(() => old.session);
      final provider = categoryDetailViewModelProvider(args);
      final emissions = <AsyncValue<CategoryDetailViewState>>[];
      final subscription = container.listen(
        provider,
        (_, next) => emissions.add(next),
      );
      addTearDown(subscription.close);
      await pumpEventQueue();
      expect(oldRunner.pending, hasLength(1));

      container
          .read(sessionHolderProvider.notifier)
          .replace(replacement.session);
      await pumpEventQueue();
      old.ledger.addEntry(lunch('-1'));
      oldRunner.pending.single.complete(const []);
      await pumpEventQueue();
      final state = await container.read(provider.future);

      expect(emissions.any((value) => value is AsyncError), isFalse);
      expect(old.ledger.listeners, 0);
      expect(old.cache.listeners, 0);
      expect(replacement.ledger.listeners, 1);
      expect(replacement.cache.listeners, 1);
      expect(state.totals.scopeTotal, Decimal.parse('7'));
    },
    timeout: uiTestTimeout,
  );
}
