import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/shell_sheet_harness.dart';

final budgetShellModeFixture = StateProvider<ShellLayoutMode>(
  (ref) => ShellLayoutMode.phone,
);

final budgetShellLedgerFixture = StateProvider<Ledger?>((ref) => null);

final budgetShellFood = TransactionCategory(
  id: 'c0000000-0000-0000-0000-000000000001',
  name: 'Food',
  kind: CategoryKind.expense,
  colorHex: '#00AA00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
);

final budgetShellAccount = Account(
  id: 'a0000000-0000-0000-0000-000000000001',
  name: 'Checking',
  type: AccountType.checking,
);

Budget buildShellBudget({
  required String id,
  String? categoryID,
  int limit = 100,
}) => Budget(id: id, categoryID: categoryID, limit: Decimal.fromInt(limit));

Ledger buildShellLedger() => Ledger(
  state: LedgerState(
    moneySources: {
      budgetShellAccount.id: MoneySource.account(budgetShellAccount),
    },
    categories: {budgetShellFood.id: budgetShellFood},
    budgets: {
      'b1': buildShellBudget(id: 'b1'),
      'b2': buildShellBudget(
        id: 'b2',
        categoryID: budgetShellFood.id,
        limit: 50,
      ),
    },
  ),
);

ProviderContainer buildShellContainer({
  required Ledger ledger,
  ComputeRunner? runner,
  List<Override> overrides = const [],
}) {
  final providerOverrides = <Override>[
    ledgerProvider.overrideWith((ref) => ref.watch(budgetShellLedgerFixture)),
    analysisComputeRunnerProvider.overrideWithValue(
      runner ?? syncComputeRunner,
    ),
    todayProvider.overrideWithValue(DateTime.utc(2026, 3, 3)),
    selectedMonthProvider.overrideWith((ref) => DateTime.utc(2026, 3)),
    shellLayoutModeProvider.overrideWith(
      (ref) => ref.watch(budgetShellModeFixture),
    ),
    ...overrides,
  ];
  final container = ProviderContainer(overrides: providerOverrides);
  addTearDown(container.dispose);
  container.read(budgetShellLedgerFixture.notifier).state = ledger;
  return container;
}

const _wideViewSize = Size(1024, 800);

ProviderContainer _shellContainer({
  required Ledger ledger,
  ComputeRunner? runner,
  TargetPlatform? platform,
}) {
  final observer = MoneyNavigatorObserver();
  final overrides = <Override>[
    moneyNavigatorObserverProvider.overrideWithValue(observer),
  ];
  if (platform != null) {
    final facts = (isWeb: false, targetPlatform: platform);
    overrides.add(shellPlatformProvider.overrideWithValue(facts));
  }
  return buildShellContainer(
    ledger: ledger,
    runner: runner,
    overrides: overrides,
  );
}

Future<ProviderContainer> pumpBudgetShell(
  WidgetTester tester, {
  required ShellLayoutMode mode,
  ComputeRunner? runner,
  Ledger? ledger,
  TargetPlatform? platform,
}) async {
  useShellWindow(tester, _wideViewSize);
  final container = _shellContainer(
    ledger: ledger ?? buildShellLedger(),
    runner: runner,
    platform: platform,
  );
  container.read(budgetShellModeFixture.notifier).state = mode;
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  container.read(moneySegmentProvider.notifier).state = MoneySegment.budgets;
  final observer = container.read(moneyNavigatorObserverProvider);
  final bodies = <ShellDestination, WidgetBuilder>{
    ShellDestination.money: (_) => MoneyFlow(moneyObserver: observer),
  };
  await pumpShellApp(tester, container, bodies: bodies);
  return container;
}

Future<void> chooseEditAction(WidgetTester tester, String label) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> tapBudget(WidgetTester tester, String budgetID) async {
  await tester.tap(find.byKey(ValueKey('budget-$budgetID')));
  await tester.pumpAndSettle();
}
