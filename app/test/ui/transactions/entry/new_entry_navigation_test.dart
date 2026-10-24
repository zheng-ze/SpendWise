import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/phone_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

void main() {
  testWidgets('open rail destination selects and dismisses Add', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: openSize);
    await tester.tap(
      find.descendant(of: find.byKey(openRailKey), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();
    final addForm = tester.state(find.byKey(newEntryFormKey));

    await resize(tester, const Size(600, 480));
    expect(tester.state(find.byKey(newEntryFormKey)), same(addForm));
    expect(harness.recorder.sheetPushes, 1);

    await resize(tester, openSize);
    expect(tester.state(find.byKey(newEntryFormKey)), same(addForm));

    await tester.tap(
      find.descendant(
        of: find.byKey(openRailKey),
        matching: find.text('History'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('outside tap dismisses Add without changing destination', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: openSize);
    await tester.tap(
      find.descendant(of: find.byKey(openRailKey), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(120, 120));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsNothing);
    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
  }, timeout: uiTestTimeout);

  testWidgets('open rail destination closes an Add picker with Add', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: openSize);
    final rail = find.byKey(openRailKey);
    await tester.tap(find.descendant(of: rail, matching: find.text('Add')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Category'));
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNWidgets(2));

    await tester.tap(find.descendant(of: rail, matching: find.text('History')));
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('phone destination selects and dismisses Add', (tester) async {
    final harness = await pumpShell(tester);
    final phoneBar = find.byType(PhoneBar);
    await tester.tap(find.descendant(of: phoneBar, matching: find.text('Add')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: phoneBar, matching: find.text('History')),
    );
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('desktop destination selects and dismisses Add', (tester) async {
    final harness = await pumpShell(
      tester,
      size: const Size(1280, 800),
      platform: TargetPlatform.macOS,
    );
    final sidebar = find.byType(DesktopSidebar);
    await tester.tap(
      find.descendant(of: sidebar, matching: find.text('Add entry')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: sidebar, matching: find.text('History')),
    );
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);
}
