import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';

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

  Counted counted() {
    return countedSession(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
      ),
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
    final app = MaterialApp(home: home);
    final scope = UncontrolledProviderScope(container: container, child: app);
    return tester.pumpWidget(scope);
  }

  testWidgets(
    'closing disposes detail providers and reopening resets scope with current queries',
    (tester) async {
      final env = counted();
      final container = containerFor(() => env.session);
      final queriesSubscription = container.listen(
        analysisQueriesProvider,
        (_, _) {},
      );
      addTearDown(queriesSubscription.close);
      final queries = container.read(analysisQueriesProvider);
      final baselineLedger = env.ledger.listeners;
      final baselineCache = env.cache.listeners;
      await pumpRoute(tester, container);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(container.exists(categoryDetailViewModelProvider(args)), isTrue);
      final viewModel = container.read(
        categoryDetailViewModelProvider(args).notifier,
      );
      viewModel.setScope(const DirectScope());
      await tester.pumpAndSettle();
      expect(
        container.read(categoryDetailIntentProvider(args)).scope,
        const DirectScope(),
      );

      Navigator.of(tester.element(find.byType(CategoryDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(container.exists(categoryDetailViewModelProvider(args)), isFalse);
      expect(container.exists(categoryDetailIntentProvider(args)), isFalse);
      expect(container.read(analysisQueriesProvider), same(queries));
      expect(env.ledger.listeners, baselineLedger);
      expect(env.cache.listeners, baselineCache);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      env.ledger.addEntry(lunch('-12'));
      await tester.pumpAndSettle();
      final reopened = container
          .read(categoryDetailViewModelProvider(args))
          .value!;
      final body = reopened.body as CategoryDetailReadyBody;
      expect(reopened.scope, const AllScope());
      expect(body.sourceRevision, env.ledger.revision);
      expect(body.totals.scopeTotal, Decimal.fromInt(12));
      expect(body.sections.single.rows.single.title, 'Lunch');
    },
    timeout: uiTestTimeout,
  );
}
