import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail_screen.dart';
import 'package:spendwise/ui/stats/stats_flow.dart';
import 'package:spendwise/ui/stats/stats_root_view_model.dart';

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

  Ledger buildLedger() {
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
        categories: {food.id: food},
      ),
    );
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester, Ledger ledger) async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisCacheProvider.overrideWith(
          (ref) => AnalysisCache(runner: syncComputeRunner),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StatsFlow()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('CategoryDetailRequested pushes CategoryDetailScreen for that '
      'category', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container
        .read(statsRootViewModelProvider.notifier)
        .requestCategoryDetail(
          kind: CategoryKind.expense,
          mainID: food.id,
          isYearRange: false,
          initialDate: DateTime.utc(2026, 3),
        );
    await tester.pumpAndSettle();

    expect(find.byType(CategoryDetailScreen), findsOneWidget);
    // Step is cleared once the Flow has acted on it, so a later rebuild
    // does not push a second time.
    expect(container.read(statsRootViewModelProvider).value?.step, isNull);
  });
}
