import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_host.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';

import '../../../support/edit_entry_harness.dart';
import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _loadError = "Couldn't load the entry form";

class _LedgerHolder extends Notifier<Ledger?> {
  @override
  Ledger? build() => null;

  void restore(Ledger ledger) => state = ledger;
}

final _ledgerHolder = NotifierProvider<_LedgerHolder, Ledger?>(
  _LedgerHolder.new,
);

void main() {
  testWidgets('a failed load shows Retry, and Retry with the ledger restored '
      'shows the form', (tester) async {
    final entry = editableEntry();
    final ledger = editLedger([entry]);
    await pumpApp(
      tester,
      Material(
        child: EditEntryHost(
          entryId: entry.id,
          frame: EntryFormFrame.pane,
          onDismiss: () {},
        ),
      ),
      overrides: [
        ledgerProvider.overrideWith((ref) => ref.watch(_ledgerHolder)),
      ],
      settle: false,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_loadError), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditEntryHost)),
    );
    container.read(_ledgerHolder.notifier).restore(ledger);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_loadError), findsNothing);
    expect(find.text('Update entry'), findsOneWidget);
  }, timeout: uiTestTimeout);
}
