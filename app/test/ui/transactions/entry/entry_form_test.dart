import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';

import '../../../support/ui_test_timeout.dart';

void main() {
  testWidgets('system entries keep protected fields locked in edit mode', (
    tester,
  ) async {
    const sourceId = 'a0000000-0000-0000-0000-000000000001';
    final entry = Entry(
      amount: Decimal.parse('250'),
      name: 'Opening balance',
      sourceID: sourceId,
      includeInAnalysis: false,
      systemKind: SystemEntryKind.openingBalance,
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {
          sourceId: MoneySource.account(
            Account(id: sourceId, name: 'Checking', type: AccountType.checking),
          ),
        },
        entries: {entry.id: entry},
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerProvider.overrideWithValue(ledger),
          scanStripEnabledProvider.overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          home: Scaffold(body: EntryForm(entryId: entry.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final nameField = find.byType(TextField).at(1);
    final nameIgnore = tester.firstWidget<IgnorePointer>(
      find.ancestor(of: nameField, matching: find.byType(IgnorePointer)),
    );
    final categoryTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Category'),
    );
    final analysisSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Include in Analysis'),
    );

    expect(nameIgnore.ignoring, isTrue);
    expect(categoryTile.onTap, isNull);
    expect(analysisSwitch.onChanged, isNull);
  }, timeout: uiTestTimeout);
}
