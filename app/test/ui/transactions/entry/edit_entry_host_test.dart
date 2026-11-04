import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_host.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
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

const _supersededKey = ValueKey('superseded-host');
const _ownerKey = ValueKey('owner-host');
const _supersededSlotKey = ValueKey('superseded-slot');
const _ownerSlotKey = ValueKey('owner-slot');

class _TwoHosts extends StatelessWidget {
  const _TwoHosts({required this.entryId, required this.showSuperseded});

  final String entryId;
  final ValueListenable<bool> showSuperseded;

  @override
  Widget build(BuildContext context) {
    final superseded = EditEntryHost(
      key: _supersededKey,
      entryId: entryId,
      frame: EntryFormFrame.pane,
      onDismiss: () {},
    );
    final owner = EditEntryHost(
      key: _ownerKey,
      entryId: entryId,
      frame: EntryFormFrame.pane,
      onDismiss: () {},
    );
    final supersededSlot = Expanded(key: _supersededSlotKey, child: superseded);
    final ownerSlot = Expanded(key: _ownerSlotKey, child: owner);
    final column = ValueListenableBuilder<bool>(
      valueListenable: showSuperseded,
      builder: (_, show, _) =>
          Column(children: [if (show) supersededSlot, ownerSlot]),
    );
    return Material(child: column);
  }
}

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

  testWidgets('only the host that owns the entry dispatches a Step', (
    tester,
  ) async {
    final entry = editableEntry();
    final ledger = editLedger([entry]);
    final showSuperseded = ValueNotifier(true);
    addTearDown(showSuperseded.dispose);
    await pumpApp(
      tester,
      _TwoHosts(entryId: entry.id, showSuperseded: showSuperseded),
      ledger: ledger,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(_ownerKey)),
    );
    final provider = entryFormViewModelProvider(entry.id);

    container.read(provider.notifier).requestPickCategory();
    await tester.pumpAndSettle();
    showSuperseded.value = false;
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
    expect(container.read(provider).value!.categoryId, editCoffee.id);
  }, timeout: uiTestTimeout);
}
