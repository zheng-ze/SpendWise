import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_alert.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_chrome.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_form.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _loadAlert = SheetAlertData(
  message: "Couldn't load the entry form",
  severity: SheetAlertSeverity.error,
  actionLabel: 'Retry',
);

class _PaneForm extends ConsumerWidget {
  const _PaneForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(entryFormViewModelProvider(null)).value;
    if (state == null) return const SizedBox.shrink();

    return NewEntryForm(
      formKey: null,
      viewModel: ref.read(entryFormViewModelProvider(null).notifier),
      state: state,
      display: ref.watch(entryFormDisplayProvider(null)),
      frame: EntryFormFrame.pane,
      alert: _loadAlert,
      onAlertAction: () {},
    );
  }
}

Widget _inOpenPane(Widget child) => ShellLayoutModeScope(
  mode: ShellLayoutMode.open,
  child: Material(child: SizedBox(width: 400, height: 700, child: child)),
);

void main() {
  testWidgets('pane loading form shows the alert and Retry without a sheet', (
    tester,
  ) async {
    var retried = 0;
    final form = NewEntryLoadingForm(
      frame: EntryFormFrame.pane,
      title: editEntryTitle,
      alert: _loadAlert,
      onAlertAction: () => retried++,
    );

    await pumpApp(tester, _inOpenPane(form), settle: false);
    await tester.tap(find.text('Retry'));

    expect(tester.takeException(), isNull);
    expect(find.byType(AppSheet), findsNothing);
    expect(find.byType(AppSheetAlertSlot), findsNothing);
    expect(find.text("Couldn't load the entry form"), findsOneWidget);
    expect(find.text('Update entry'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(retried, 1);
  }, timeout: uiTestTimeout);

  testWidgets('pane form renders Add copy and the save alert without a sheet', (
    tester,
  ) async {
    await pumpApp(
      tester,
      _inOpenPane(const _PaneForm()),
      ledger: Ledger(state: LedgerState()),
      overrides: [scanStripEnabledProvider.overrideWith((ref) async => true)],
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppSheet), findsNothing);
    expect(find.byType(AppSheetAlertSlot), findsNothing);
    expect(find.text('Save entry'), findsOneWidget);
    expect(find.text("Couldn't load the entry form"), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  }, timeout: uiTestTimeout);
}
