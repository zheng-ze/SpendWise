import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_screen.dart';

import '../../../support/ledger_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _restoreLabel = 'Restore';
const _launchLabel = 'Open bin';

class _BinLauncher extends StatelessWidget {
  const _BinLauncher();

  @override
  Widget build(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (_) => const RecycleBinScreen(),
    );
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(route),
        child: const Text(_launchLabel),
      ),
    );
  }
}

Account _account(String name, {LifecycleState? lifecycle}) => testAccount(
  name: name,
  type: AccountType.checking,
  lifecycle: lifecycle ?? LifecycleState.active,
);

Entry _entry(String name, String sourceID) => testEntry(
  amount: Decimal.parse('-5'),
  name: name,
  sourceID: sourceID,
  date: DateTime.utc(2026, 1, 5),
);

TransactionCategory _category(String name, {LifecycleState? lifecycle}) =>
    testCategory(
      name: name,
      colorHex: '#FF0000',
      lifecycle: lifecycle ?? LifecycleState.active,
    );

Ledger _ledgerOf({
  List<Account> accounts = const [],
  List<TransactionCategory> categories = const [],
  List<Entry> entries = const [],
  List<Entry> binnedEntries = const [],
}) => Ledger(
  state: LedgerState(
    moneySources: {for (final a in accounts) a.id: MoneySource.account(a)},
    categories: {for (final c in categories) c.id: c},
    entries: {for (final e in entries) e.id: e},
    binnedEntries: {for (final e in binnedEntries) e.id: e},
  ),
);

Future<void> _pump(WidgetTester tester, Ledger ledger) =>
    pumpApp(tester, const RecycleBinScreen(), ledger: ledger);

void main() {
  testWidgets('a row Restore action restores the binned account', (
    tester,
  ) async {
    final account = _account('Old savings', lifecycle: LifecycleState.archived);
    final ledger = _ledgerOf(accounts: [account]);
    await _pump(tester, ledger);

    await tester.tap(find.text(_restoreLabel));
    await tester.pumpAndSettle();

    final restored = ledger.state.moneySources[account.id]!;
    expect(restored.lifecycle, LifecycleState.active);
    expect(find.text('Old savings'), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('an entry row Restore action restores the binned entry', (
    tester,
  ) async {
    final account = _account('Cash');
    final entry = _entry('Hawker lunch', account.id);
    final ledger = _ledgerOf(accounts: [account], binnedEntries: [entry]);
    await _pump(tester, ledger);

    await tester.tap(find.text(_restoreLabel));
    await tester.pumpAndSettle();

    expect(ledger.state.entries.containsKey(entry.id), isTrue);
    expect(ledger.state.binnedEntries, isEmpty);
  }, timeout: uiTestTimeout);

  testWidgets('a category row Restore action restores the binned category', (
    tester,
  ) async {
    final category = _category('Fitness', lifecycle: LifecycleState.archived);
    final ledger = _ledgerOf(categories: [category]);
    await _pump(tester, ledger);

    await tester.tap(find.text(_restoreLabel));
    await tester.pumpAndSettle();

    final restored = ledger.state.categories[category.id]!;
    expect(restored.lifecycle, LifecycleState.active);
  }, timeout: uiTestTimeout);

  testWidgets(
    'the header shows the title and a Settings back control that pops',
    (tester) async {
      await pumpApp(tester, const _BinLauncher(), ledger: _ledgerOf());
      await tester.tap(find.text(_launchLabel));
      await tester.pumpAndSettle();
      expect(find.byType(RecycleBinScreen), findsOneWidget);
      expect(find.text('Recycle bin'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(RecycleBinScreen), findsNothing);
    },
    timeout: uiTestTimeout,
  );
}
