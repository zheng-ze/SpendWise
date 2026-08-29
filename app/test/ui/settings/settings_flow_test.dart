import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/category_list_screen.dart';
import 'package:spendwise/ui/settings/plan_list_screen.dart';
import 'package:spendwise/ui/settings/recycle_bin_screen.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Ledger buildLedger() {
    final account = Account(name: 'Checking', type: AccountType.checking);
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester, Ledger ledger) async {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsFlow()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('CategoriesRequested pushes the category list screen', (
    tester,
  ) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(settingsRootViewModelProvider.notifier).requestCategories();
    await tester.pumpAndSettle();

    expect(find.byType(CategoryListScreen), findsOneWidget);
    // Step is cleared once the Flow has acted on it, so a later rebuild
    // does not push the same screen a second time.
    expect(container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('PlansRequested pushes the plan list screen', (tester) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(settingsRootViewModelProvider.notifier).requestPlans();
    await tester.pumpAndSettle();

    expect(find.byType(PlanListScreen), findsOneWidget);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('RecycleBinRequested pushes the recycle bin screen', (
    tester,
  ) async {
    final container = await pumpFlow(tester, buildLedger());

    container.read(settingsRootViewModelProvider.notifier).requestRecycleBin();
    await tester.pumpAndSettle();

    expect(find.byType(RecycleBinScreen), findsOneWidget);
    expect(container.read(settingsRootViewModelProvider).step, isNull);
  });

  testWidgets('back navigation while the category list screen is open pops the '
      "screen, not the Flow's own root", (tester) async {
    await pumpFlow(tester, buildLedger());
    expect(find.byType(CategoryListScreen), findsNothing);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryListScreen), findsOneWidget);

    // The outer PopScope blocks this, so it must pop the pushed screen
    // inside SettingsFlow's own Navigator rather than escaping the Flow.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(CategoryListScreen), findsNothing);
    expect(find.byType(SettingsFlow), findsOneWidget);
  });
}
