import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/accounts/accounts_screen.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/settings/category/category_list_screen.dart';
import 'package:spendwise/ui/settings/category/category_list_view_model.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

import '../support/phone_shell.dart';
import '../support/ui_test_timeout.dart';

const _pastRetryDelay = Duration(seconds: 2);
const _missingLedgerMessage = 'requires a ready ledger';

final Map<String, ProviderListenable<AsyncValue<Object?>>> _tabProviders = {
  'Accounts': accountsViewModelProvider,
  'Overview': overviewViewModelProvider,
  'Category list': categoryListViewModelProvider,
  'Plan list': planListViewModelProvider,
  'Recycle bin': recycleBinViewModelProvider,
  'Budgets list': budgetsListViewModelProvider,
  'History': transactionsViewModelProvider(null),
};

Future<void> _pumpWithoutLedger(WidgetTester tester, Widget screen) async {
  final app = MaterialApp(home: phoneShell(screen));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ledgerProvider.overrideWithValue(null)],
      child: app,
    ),
  );
  await tester.pump();
}

void main() {
  for (final MapEntry(:key, :value) in _tabProviders.entries) {
    test('$key view model whose build throws stays AsyncError, not '
        'AsyncLoading', () async {
      final container = ProviderContainer(
        overrides: [ledgerProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      container.listen(value, (previous, next) {}, onError: (_, _) {});

      container.read(value);
      await Future<void>.delayed(_pastRetryDelay);
      final state = container.read(value);

      expect(state, isA<AsyncError<Object?>>());
      expect(state.isLoading, isFalse);
      expect('${state.error}', contains(_missingLedgerMessage));
    });
  }

  testWidgets(
    'Accounts screen shows the error when its view model build throws',
    (tester) async {
      await _pumpWithoutLedger(tester, const AccountsScreen());

      expect(find.textContaining(_missingLedgerMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Category list screen shows the error when its view model build throws',
    (tester) async {
      await _pumpWithoutLedger(tester, const CategoryListScreen());

      expect(find.textContaining(_missingLedgerMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}
