import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/app_settings.dart';
import 'package:spendwise/ui/settings/settings_root_screen.dart';

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

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(buildLedger())],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the scan strip toggle, on by default', (tester) async {
    await pumpSettings(tester);

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isTrue);
  });

  testWidgets('tapping the toggle persists the new value via AppSettings', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
    expect(await const AppSettings().scanStripEnabled(), isFalse);
  });
}
