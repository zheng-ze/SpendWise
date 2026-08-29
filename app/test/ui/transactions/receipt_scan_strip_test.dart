import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_strip.dart';

void main() {
  Ledger buildLedger() {
    final account = Account(name: 'Checking', type: AccountType.checking);
    return Ledger(
      state: LedgerState(
        moneySources: {account.id: MoneySource.account(account)},
      ),
    );
  }

  Future<void> pumpStrip(WidgetTester tester, {required bool enabled}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(buildLedger()),
          scanStripEnabledProvider.overrideWith((ref) async => enabled),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ReceiptScanStrip(formKey: null)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows both buttons when the setting is on (non-web)', (
    tester,
  ) async {
    await pumpStrip(tester, enabled: true);

    expect(find.text('Scan receipt'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);
  });

  testWidgets('renders nothing when the setting is off', (tester) async {
    await pumpStrip(tester, enabled: false);

    expect(find.text('Scan receipt'), findsNothing);
    expect(find.text('Upload photo'), findsNothing);
  });
}
