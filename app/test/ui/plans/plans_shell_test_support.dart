import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/ui/money/money_segment.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/shell_sheet_harness.dart';

final plansShellModeFixture = StateProvider<ShellLayoutMode>(
  (ref) => ShellLayoutMode.phone,
);

final plansShellLedgerFixture = StateProvider<Ledger?>((ref) => null);

final plansShellToday = DateTime.utc(2026, 3, 3);

final plansShellChecking = Account(
  id: 'a0000000-0000-0000-0000-000000000001',
  name: 'Checking',
  type: AccountType.checking,
);

final plansShellSavings = Account(
  id: 'a0000000-0000-0000-0000-000000000002',
  name: 'Savings',
  type: AccountType.savings,
);

final plansShellFitness = TransactionCategory(
  id: 'c0000000-0000-0000-0000-000000000001',
  name: 'Fitness',
  kind: CategoryKind.expense,
  colorHex: '#00AA00',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
  lifecycle: LifecycleState.archived,
);

const plansShellWindow = Size(1024, 800);

RecurringPlan buildShellPlan({
  required String id,
  required String name,
  required String amount,
  required DateTime anchor,
  String? destinationID,
  String? categoryID,
}) => RecurringPlan(
  id: id,
  template: EntryTemplate(
    amount: Decimal.parse(amount),
    name: name,
    sourceID: plansShellChecking.id,
    destinationID: destinationID,
    categoryID: categoryID,
  ),
  frequency: RecurrenceFrequency.monthly,
  anchor: anchor,
  lastResolvedDate: anchor.subtract(const Duration(days: 1)),
);

final plansShellExpensePlan = buildShellPlan(
  id: 'b0000000-0000-0000-0000-000000000001',
  name: 'Rent',
  amount: '-1200',
  anchor: DateTime.utc(2026, 3, 5),
);

final plansShellIncomePlan = buildShellPlan(
  id: 'b0000000-0000-0000-0000-000000000002',
  name: 'Salary',
  amount: '3000',
  anchor: DateTime.utc(2026, 3, 25),
);

final plansShellTransferPlan = buildShellPlan(
  id: 'b0000000-0000-0000-0000-000000000003',
  name: 'To savings',
  amount: '-500',
  anchor: DateTime.utc(2026, 3, 10),
  destinationID: plansShellSavings.id,
);

final plansShellBinnedCategoryPlan = buildShellPlan(
  id: 'b0000000-0000-0000-0000-000000000004',
  name: 'Gym membership',
  amount: '-60',
  anchor: DateTime.utc(2026, 3, 7),
  categoryID: plansShellFitness.id,
);

Ledger buildPlansShellLedger({List<RecurringPlan>? plans}) {
  final coffee = Entry(
    date: DateTime.utc(2026, 3, 1),
    amount: Decimal.parse('-5'),
    name: 'Coffee',
    sourceID: plansShellChecking.id,
  );
  return Ledger(
    state: LedgerState(
      moneySources: {
        plansShellChecking.id: MoneySource.account(plansShellChecking),
        plansShellSavings.id: MoneySource.account(plansShellSavings),
      },
      categories: {plansShellFitness.id: plansShellFitness},
      entries: {coffee.id: coffee},
      plans: {for (final plan in plans ?? _seededPlans) plan.id: plan},
    ),
  );
}

final _seededPlans = [
  plansShellIncomePlan,
  plansShellExpensePlan,
  plansShellTransferPlan,
];

Future<ProviderContainer> pumpPlansShell(
  WidgetTester tester, {
  required ShellLayoutMode mode,
  required Ledger ledger,
  required Brightness brightness,
  Size size = plansShellWindow,
}) async {
  useShellWindow(tester, size);
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWith((ref) => ref.watch(plansShellLedgerFixture)),
      todayProvider.overrideWithValue(plansShellToday),
      shellLayoutModeProvider.overrideWith(
        (ref) => ref.watch(plansShellModeFixture),
      ),
      moneySegmentProvider.overrideWith((ref) => MoneySegment.plans),
    ],
  );
  addTearDown(container.dispose);
  container.read(plansShellLedgerFixture.notifier).state = ledger;
  container.read(plansShellModeFixture.notifier).state = mode;
  container.read(selectedDestinationProvider.notifier).state =
      ShellDestination.money;
  final bodies = <ShellDestination, WidgetBuilder>{
    ShellDestination.money: (_) => const MoneyFlow(),
  };
  await pumpShellApp(tester, container, bodies: bodies, brightness: brightness);
  return container;
}

Future<void> tapPlan(WidgetTester tester, String planID) async {
  await tester.tap(find.byKey(ValueKey('plan-$planID')));
  await tester.pumpAndSettle();
}
