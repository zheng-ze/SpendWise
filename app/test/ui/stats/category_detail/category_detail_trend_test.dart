import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_screen.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

const _timeout = Duration(seconds: 10);
const _mainID = 'a0000000-0000-0000-0000-000000000001';
const _accountID = 'a0000000-0000-0000-0000-000000000002';
const _entryMarchID = 'a0000000-0000-0000-0000-000000000003';
const _entryAprilID = 'a0000000-0000-0000-0000-000000000004';

void main() {
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
    expect(initialBody.trend!.selection, isNull);
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
  return Ledger(
    state: LedgerState(
      moneySources: {_accountID: MoneySource.account(account)},
      categories: {_mainID: food},
      entries: {_entryMarchID: march, _entryAprilID: april},
    ),
  );
}
