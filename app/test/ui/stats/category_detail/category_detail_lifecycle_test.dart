import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ledger/ledger_session.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';

import '../../../support/ui_test_timeout.dart';

class _CountingLedger extends Ledger {
  _CountingLedger({super.state});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

class _CountingCache extends AnalysisCache {
  _CountingCache({super.runner});

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

class _SessionHolder extends Notifier<LedgerSession?> {
  @override
  LedgerSession? build() => null;

  void replace(LedgerSession session) => state = session;
}

final _sessionHolderProvider = NotifierProvider<_SessionHolder, LedgerSession?>(
  _SessionHolder.new,
);

class _ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];

  Future<List<AnalysisItem>> call(LedgerState state) {
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

class _Counted {
  _Counted(this.ledger, this.cache);

  final _CountingLedger ledger;
  final _CountingCache cache;

  LedgerSession get session =>
      LedgerSession(ledger: ledger, analysisCache: cache);
}

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

  _Counted counted({
    ComputeRunner runner = syncComputeRunner,
    Map<String, Entry> entries = const {},
  }) {
    final ledger = _CountingLedger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
        entries: entries,
      ),
    );
    final cache = _CountingCache(runner: runner);
    cache.start(ledger.bus, sourceRevision: () => ledger.revision);
    addTearDown(cache.dispose);
    return _Counted(ledger, cache);
  }

  ProviderContainer containerFor(LedgerSession Function() session) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWith(
          (ref) => ref.watch(_sessionHolderProvider)?.ledger,
        ),
        ledgerSessionProvider.overrideWith(
          (ref) => ref.watch(_sessionHolderProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(_sessionHolderProvider.notifier).replace(session());
    return container;
  }

  testWidgets(
    'closing the route releases listeners and reopening still updates',
    (tester) async {
      final env = counted();
      final container = containerFor(() => env.session);
      final baselineLedger = env.ledger.listeners;
      final baselineCache = env.cache.listeners;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryDetailScreen(args: args),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

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
      final runner = _ManualRunner();
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
      final oldRunner = _ManualRunner();
      final old = counted(runner: oldRunner.call);
      final replacement = counted(entries: {lunch('-7').id: lunch('-7')});
      final container = containerFor(() => old.session);
      final provider = categoryDetailViewModelProvider(args);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await pumpEventQueue();
      expect(oldRunner.pending, hasLength(1));

      container
          .read(_sessionHolderProvider.notifier)
          .replace(replacement.session);
      await pumpEventQueue();
      old.ledger.addEntry(lunch('-1'));
      oldRunner.pending.single.complete(const []);
      final state = await container.read(provider.future);

      expect(old.ledger.listeners, 0);
      expect(old.cache.listeners, 0);
      expect(replacement.ledger.listeners, 1);
      expect(replacement.cache.listeners, 1);
      expect(state.totals.scopeTotal, Decimal.parse('7'));
    },
    timeout: uiTestTimeout,
  );
}
